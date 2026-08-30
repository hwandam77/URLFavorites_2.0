# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module Search
      class EmbeddingClient
        # 2026-08-30 인프라 이전으로 임베딩 서버 소실 후 재구축하며 bge-m3로 교체.
        # 1024차원은 교체 전(nomic 계열 아닌 1024차원 모델)과 동일.
        # nomic-embed-text는 영어 중심이라 한국어 무의미 질의 분리가 불가했음 (유효/무의미 최고 유사도 0.75 부근 겹침).
        EMBEDDING_MODEL = "bge-m3".freeze
        EMBEDDING_URL = ENV["EMBEDDING_URL"] || ENV["LLAMA_SERVER_URL"] || "http://localhost:8080"

        def self.call(text)
          new.call(text)
        end

        def call(text)
          return [] if text.blank?

          truncated = text[0...8000]

          conn = Faraday.new(EMBEDDING_URL) do |f|
            f.options.timeout = 60
            f.request :json
            f.response :raise_error
          end

          body = { model: EMBEDDING_MODEL, input: truncated }
          response = conn.post("/v1/embeddings", body)
          parsed = JSON.parse(response.body, symbolize_names: true)
          parsed.dig(:data, 0, :embedding) || []
        rescue => e
          Rails.logger.error "[EmbeddingClient] Error: #{e.message}"
          []
        end
      end
    end
  end
end
