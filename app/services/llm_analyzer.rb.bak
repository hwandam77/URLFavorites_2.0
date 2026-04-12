class LlmAnalyzer
  class ParseError < StandardError; end
  class ServerError < StandardError; end

  def self.call(content, type:)
    base_url = ENV["LLAMA_SERVER_URL"].presence
    raise ArgumentError, "LLAMA_SERVER_URL is not set" unless base_url

    conn = Faraday.new(base_url) do |f|
      f.options.timeout      = 120
      f.options.open_timeout = 10
      f.request :json
      f.response :raise_error
    end

    body = {
      model: "local",
      messages: [ { role: "user", content: "#{type}: #{content}" } ],
      response_format: { type: "json_object" }
    }

    response = conn.post("/v1/chat/completions", body)

    raise ServerError, "LLM server error: #{response.status}" if response.status >= 500

    parsed = JSON.parse(response.body, symbolize_names: true)

    required = %i[summary key_points tags sentiment]
    missing  = required - parsed.keys
    raise ParseError, "Missing keys: #{missing.join(", ")}" if missing.any?

    parsed.slice(:summary, :key_points, :tags, :sentiment)
  rescue Faraday::ServerError => e
    raise ServerError, "HTTP server error: #{e.message}"
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON: #{e.message}"
  rescue Faraday::Error => e
    raise ServerError, "Connection error: #{e.message}"
  end
end
