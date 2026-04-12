class LlmAnalyzer
  class ParseError < StandardError; end
  class ServerError < StandardError; end

  # Primary/backup backends: Nexus LLM → Local llama-server → Cloud API
  # URL은 환경변수 LLM_BACKENDS로 덮어쓰기 가능, 없으면 ENV["LLAMA_SERVER_URL"] 또는 localhost 사용
  DEFAULT_BASE_URL = "http://localhost:8080"

  # Default backend configuration (used when LLM_BACKENDS env var is not set)
  # Note: URL is resolved lazily in resolve_backends to respect runtime ENV changes
  DEFAULT_BACKENDS = [
    { model: "local", timeout: 120 }
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

  # Class-level connection cache to avoid repeated connection creation
  # Keyed by base_url to support multiple backends
  @@connection_cache = {}
  cattr_accessor :connection_cache, instance_reader: false, instance_writer: false

  def self.attempt_backend(backend, content, type)
    base_url = backend[:url]
    timeout = backend[:timeout] || 120
    model = backend[:model] || "local"

    # Reuse cached connection or create new one
    @@connection_cache[base_url] ||= Faraday.new(base_url) do |f|
      f.options.timeout      = timeout
      f.options.open_timeout = 10
      f.request :json
      f.response :raise_error
    end
    conn = @@connection_cache[base_url]
    # Update timeout for this specific request
    conn.options.timeout = timeout

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

    if response.status >= 500
      Rails.logger.warn "[LlmAnalyzer] Backend #{base_url} returned #{response.status}"
      return nil
    end

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
        if b.is_a?(Hash)
          b.symbolize_keys
        elsif b.is_a?(String)
          # If it's a string that looks like JSON, parse it; otherwise treat as URL
          begin
            JSON.parse(b).symbolize_keys
          rescue JSON::ParserError
            { url: b, model: "default", timeout: 60 }
          end
        else
          raise ParseError, "Invalid backend config: #{b.inspect}"
        end
      end
    else
      DEFAULT_BACKENDS.map { |b| b.merge(url: ENV["LLAMA_SERVER_URL"]) }.select { |b| b[:url].present? }
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