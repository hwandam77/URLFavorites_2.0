# frozen_string_literal: true

class EmbeddingService
  # Generates embeddings for content using LLM
  # Uses lightweight model for fast semantic search

  EMBEDDING_MODEL = "nomic-embed-text".freeze
  EMBEDDING_URL = ENV["EMBEDDING_URL"] || ENV["LLAMA_SERVER_URL"] || "http://localhost:8080"

  def self.call(text)
    new.call(text)
  end

  def call(text)
    return [] if text.blank?

    # Truncate to reasonable length
    truncated = text[0...8000]

    conn = Faraday.new(EMBEDDING_URL) do |f|
      f.options.timeout = 60
      f.request :json
      f.response :raise_error
    end

    body = {
      model: EMBEDDING_MODEL,
      prompt: truncated
    }

    response = conn.post("/v1/embeddings", body)
    parsed = JSON.parse(response.body, symbolize_names: true)

    parsed[:embedding] || []
  rescue => e
    Rails.logger.error "[EmbeddingService] Error: #{e.message}"
    []
  end
end
