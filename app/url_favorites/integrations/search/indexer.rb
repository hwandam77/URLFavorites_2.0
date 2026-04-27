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

          content_for_embedding = [favorite.title, summary, note].compact.join(" ")
          embedding = UrlFavorites::Integrations::Search::EmbeddingClient.call(content_for_embedding)
          embedding_json = embedding.present? ? embedding.to_json : nil

          conn.execute("DELETE FROM favorites_fts WHERE favorite_id = #{favorite.id}")

          conn.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [
              "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
              favorite.id, favorite.title, summary, tags, note, embedding_json
            ])
          )
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
