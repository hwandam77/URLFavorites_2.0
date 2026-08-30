# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module Search
      class SemanticClient
        # 코사인 유사도 하한. 아래는 무관한 결과로 간주해 버린다.
        # 2026-08-03 운영 293건 실측(nomic→1024차원 모델): 무의미 질의 최고 0.376~0.414, 유효 질의 최고 0.487~0.668 → 0.45 채택.
        # 2026-08-30 bge-m3 재구축 후 재측정(377건): 무의미 최고 0.454, 유효 최저 0.492 → 0.47로 상향.
        # 임베딩 모델이나 코퍼스가 바뀌면 재측정해서 조정할 것.
        SIMILARITY_THRESHOLD = 0.47

        def self.call(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
          new(query: query, content_type: content_type, status: status,
              collection_id: collection_id, sort: sort, limit: limit).call
        end

        def initialize(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
          @query = query.to_s.strip
          @content_type = content_type
          @status = status
          @collection_id = collection_id
          @sort = sort
          @limit = limit
        end

        def call
          return [] if @query.blank?

          query_embedding = UrlFavorites::Integrations::Search::EmbeddingClient.call(@query)
          return [] if query_embedding.empty?

          candidates = fetch_candidates_with_embeddings

          scored = candidates.map do |candidate|
            embedding = parse_embedding(candidate[:content_embedding])
            next unless embedding.present?

            similarity = cosine_similarity(query_embedding, embedding)
            candidate.merge(similarity: similarity)
          end.compact

          scored = scored.select { |c| c[:similarity] >= SIMILARITY_THRESHOLD }
          scored = scored.sort_by { |c| -c[:similarity] }
          return [] if scored.empty?

          favorite_ids = scored.map { |c| c[:favorite_id] }
          favorites_map = Favorite.where(id: favorite_ids).index_by(&:id)

          results = scored.map { |c| favorites_map[c[:favorite_id]] }.compact

          results = filter_by_content_type(results)
          results = filter_by_status(results)
          results = filter_by_collection_id(results)

          results.first(@limit)
        end

        private

        def fetch_candidates_with_embeddings
          sql = "SELECT favorite_id, embedding FROM favorite_embeddings LIMIT 1000"
          rows = ActiveRecord::Base.connection.execute(sql)
          rows.map { |r| { favorite_id: r["favorite_id"], content_embedding: r["embedding"] } }
        end

        def parse_embedding(embedding_str)
          return [] if embedding_str.blank?
          JSON.parse(embedding_str)
        rescue JSON::ParserError
          []
        end

        def cosine_similarity(a, b)
          return 0 if a.empty? || b.empty? || a.length != b.length
          dot_product = a.zip(b).map { |x, y| x * y }.sum
          magnitude_a = Math.sqrt(a.map { |x| x**2 }.sum)
          magnitude_b = Math.sqrt(b.map { |x| x**2 }.sum)
          return 0 if magnitude_a.zero? || magnitude_b.zero?
          dot_product / (magnitude_a * magnitude_b)
        end

        def filter_by_content_type(favorites)
          return favorites unless @content_type.present?
          favorites.select { |f| f.content_type == @content_type }
        end

        def filter_by_status(favorites)
          return favorites unless @status.present?
          favorites.select { |f| f.status == @status }
        end

        def filter_by_collection_id(favorites)
          return favorites unless @collection_id.present?
          favorites.select { |f| f.collection_memberships.any? { |m| m.collection_id == @collection_id } }
        end
      end
    end
  end
end
