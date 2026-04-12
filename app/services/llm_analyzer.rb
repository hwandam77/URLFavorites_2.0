class LlmAnalyzer
  class ParseError < StandardError; end
  class ServerError < StandardError; end

  # Primary/backup backends: Nexus LLM → Local llama-server → Cloud API
  BACKENDS = [
    { url: "http://10.10.0.3:8081", model: "qwen3-30b", timeout: 60 },   # Nexus 30B
    { url: "http://10.10.0.3:8082", model: "qwen3-48b", timeout: 120 }, # Nexus 48B
  ].freeze

  def self.call(content, type:)
    backends = resolve_backends

    last_error = nil
    backends.each do |backend|
      result = attempt_backend(backend, content, type)
      return result if result
    rescue ServerError, ParseError => e
      last_error = e
      Rails.logger.warn "[LlmAnalyzer] Backend #{backend[:url]} failed: #{e.message}"
    end

    raise ServerError, "All LLM backends failed. Last error: #{last_error&.message}"
  end

  def self.attempt_backend(backend, content, type)
    base_url = backend[:url]
    timeout = backend[:timeout] || 120
    model = backend[:model] || "local"

    conn = Faraday.new(base_url) do |f|
      f.options.timeout      = timeout
      f.options.open_timeout = 10
      f.request :json
      f.response :raise_error
    end

    body = {
      model: model,
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        { role: "user", content: "#{type}: #{content}" }
      ],
      response_format: { type: "json_object" }
    }

    response = conn.post("/v1/chat/completions", body)

    return nil if response.status >= 500

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

  def self.resolve_backends
    env_backends = ENV["LLM_BACKENDS"]
    if env_backends.present?
      JSON.parse(env_backends).map do |b|
        b.is_a?(Hash) ? b.symbolize_keys : JSON.parse(b).symbolize_keys
      end
    else
      BACKENDS.select { |b| b[:url].present? }
    end
  end

  def self.system_prompt
    <<~PROMPT
      You are a content classifier for a personal bookmark manager.
      Analyze the given content and respond with valid JSON only:
      {
        "summary": "2-3 sentence summary in Korean",
        "key_points": ["point1", "point2", "point3"],
        "tags": ["tag1", "tag2", "tag3"],
        "sentiment": "positive|neutral|negative"
      }
      Rules:
      - tags: 3-7 lowercase English words or Korean words
      - summary: under 200 characters
      - key_points: max 5 items
    PROMPT
  end
end