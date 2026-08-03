module UrlFavorites
  module Integrations
    module Search
      class Indexer
        def self.index(favorite)
          analysis = favorite.analysis
          summary = analysis&.summary
          tags = analysis&.tags&.join(" ")
          note = favorite.respond_to?(:note) ? favorite.note : nil

          conn = ActiveRecord::Base.connection

          conn.execute("DELETE FROM favorites_fts WHERE favorite_id = #{favorite.id}")

          conn.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [
              "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
              favorite.id, favorite.title, summary, tags, note, nil
            ])
          )

          store_embedding(favorite)
        end

        def self.store_embedding(favorite)
          analysis = favorite.analysis
          note = favorite.respond_to?(:note) ? favorite.note : nil

          text = [ favorite.title, analysis&.summary, analysis&.tags&.join(" "), analysis&.detail_content, note ].compact.join(" ")
          embedding = UrlFavorites::Integrations::Search::EmbeddingClient.call(text)
          return if embedding.empty?

          now = Time.current
          ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [
              "INSERT INTO favorite_embeddings (favorite_id, embedding, model, dimensions, created_at, updated_at) " \
              "VALUES (?, ?, ?, ?, ?, ?) " \
              "ON CONFLICT(favorite_id) DO UPDATE SET " \
              "embedding = excluded.embedding, model = excluded.model, " \
              "dimensions = excluded.dimensions, updated_at = excluded.updated_at",
              favorite.id, embedding.to_json,
              UrlFavorites::Integrations::Search::EmbeddingClient::EMBEDDING_MODEL,
              embedding.size, now, now
            ])
          )
        end

        def self.backfill_embeddings
          Favorite.includes(:analysis).find_each { |f| store_embedding(f) }
        end

        def self.remove(favorite_id)
          ActiveRecord::Base.connection.execute(
            "DELETE FROM favorites_fts WHERE favorite_id = #{favorite_id.to_i}"
          )
        end

        def self.reindex_all
          conn = ActiveRecord::Base.connection
          conn.execute("DELETE FROM favorites_fts")

          Favorite.includes(:analysis).find_each do |favorite|
            index(favorite)
          end
        end
      end
    end
  end
end
