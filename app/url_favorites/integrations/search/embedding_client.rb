# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module Search
      class EmbeddingClient
        EMBEDDING_MODEL = "nomic-embed-text".freeze
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
