# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module LlamaServer
      class Client
        class ParseError < StandardError; end
        class ServerError < StandardError; end

        DEFAULT_BASE_URL = "http://localhost:8080"
        DEFAULT_TIMEOUT_SECONDS = 120
        DEFAULT_OPEN_TIMEOUT_SECONDS = 10

        # Default backend configuration (used when LLM_BACKENDS env var is not set)
        # Note: URL is resolved lazily in resolve_backends to respect runtime ENV changes
        DEFAULT_BACKENDS = [
          { model: "local", timeout: DEFAULT_TIMEOUT_SECONDS }
        ].freeze

        # Class-level connection cache to avoid repeated connection creation
        # Keyed by base_url to support multiple backends
        @@connection_cache = {}
        cattr_accessor :connection_cache, instance_reader: false, instance_writer: false

        def self.call(content, type:)
          backends = resolve_backends

          last_error = nil
          backends.each do |backend|
            result = attempt_backend(backend, content, type)
            return result if result
          rescue ServerError, ParseError => e
            last_error = e
            Rails.logger.warn "[LlamaServer::Client] Backend #{backend[:url]} failed: #{e.message}"
          end

          raise ServerError, "All LLM backends failed. Last error: #{last_error&.message}"
        end

        def self.attempt_backend(backend, content, type)
          base_url = backend[:url]
          timeout = backend[:timeout] || DEFAULT_TIMEOUT_SECONDS
          model = backend[:model] || "local"

          @@connection_cache[base_url] ||= Faraday.new(base_url) do |f|
            f.options.timeout      = timeout
            f.options.open_timeout = DEFAULT_OPEN_TIMEOUT_SECONDS
            f.request :json
            f.response :raise_error
          end
          conn = @@connection_cache[base_url]
          conn.options.timeout = timeout

          body = {
            model: model,
            messages: [
              { role: "system", content: system_prompt(type) },
              { role: "user", content: "#{type}: #{content}" }
            ],
            response_format: { type: "json_object" }
          }

          response = conn.post("/v1/chat/completions", body)

          parsed = JSON.parse(response.body, symbolize_names: true)
          inner = extract_result_from(parsed)
          validate_required_keys!(inner)

          result = inner.slice(:summary, :key_points, :tags, :sentiment)
          result[:detail_content] = inner[:detail_content] if inner.key?(:detail_content)
          result
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
                  { url: b, model: "default", timeout: DEFAULT_TIMEOUT_SECONDS }
                end
              else
                raise ParseError, "Invalid backend config: #{b.inspect}"
              end
            end
          else
            base_url = ENV["LLAMA_SERVER_URL"].presence || DEFAULT_BASE_URL
            DEFAULT_BACKENDS.map { |b| b.merge(url: base_url) }.select { |b| b[:url].present? }
          end
        rescue JSON::ParserError => e
          raise ParseError, "Invalid LLM_BACKENDS JSON: #{e.message}"
        end

        def self.extract_result_from(parsed)
          if parsed.is_a?(Hash) && parsed.key?(:choices)
            message_content = parsed.dig(:choices, 0, :message, :content)
            raise ParseError, "Missing message.content in response" if message_content.blank?

            json = strip_json_fences(message_content)
            JSON.parse(json, symbolize_names: true)
          else
            parsed
          end
        end

        def self.strip_json_fences(text)
          trimmed = text.to_s.strip
          return trimmed unless trimmed.start_with?("```")

          trimmed = trimmed.sub(/\A```(?:json)?\s*/i, "")
          trimmed.sub(/\s*```\z/, "")
        end

        def self.validate_required_keys!(inner)
          unless inner.is_a?(Hash)
            raise ParseError, "Expected JSON object, got: #{inner.class}"
          end

          required = %i[summary key_points tags sentiment]
          missing  = required - inner.keys
          raise ParseError, "Missing keys: #{missing.join(", ")}" if missing.any?
        end

        def self.system_prompt(type = nil)
          <<~PROMPT
            You are a content classifier for a personal bookmark manager.
            Analyze the given content and respond with valid JSON only:
            {
              "summary": "2-3 sentence summary in Korean",
              "key_points": [
                {
                  "category": "핵심 분류",
                  "point": "구체적이고 실행 가능한 핵심 내용",
                  "timestamp": "영상 근거 시간이 있으면 HH:MM:SS, 없으면 빈 문자열"
                }
              ],
              "tags": ["tag1", "tag2", "tag3"],
              "sentiment": "positive|neutral|negative",
              "detail_content": "분석 대상의 상세 내용 3~5문단"
            }
            Rules:
            - tags: 3-7 lowercase English words or Korean words
            - summary: under 200 characters
            - key_points: max 5 items
            - detail_content: 전체 핵심 내용 3~5문단으로 작성
            #{youtube_prompt_rules if type == "youtube"}
          PROMPT
        end

        def self.youtube_prompt_rules
          <<~RULES

            For YouTube content:
            - Treat the video as source material for a professional AI execution brief, not a casual summary.
            - detail_content must be a Korean markdown document with these exact section headings:
              ## 콘텐츠의 목적과 핵심 주장
              ## 영상에서 제공한 GitHub 링크
              ## 실행 가능한 절차
              ## 바로 사용 가능한 AI 프롬프트
              ## 필요한 입력값, 전제 조건, 주의할 리스크
              ## 추가로 확인하면 좋은 질문
            - In "## 영상에서 제공한 GitHub 링크", preserve only GitHub URLs explicitly present in "Provided GitHub links"; copy each URL exactly as a markdown bullet.
            - If "Provided GitHub links" is "미확인" or empty, write "미확인" in that section.
            - In "## 실행 가능한 절차", write steps a human can perform manually.
            - In "## 바로 사용 가능한 AI 프롬프트", write one complete ready-to-use prompt that another AI can execute immediately.
            - The purpose of "## 바로 사용 가능한 AI 프롬프트" is to help the user reuse the video's method on their own input or task.
            - The ready-to-use prompt must explicitly include 역할, 작업, 입력, and 출력 형식.
            - When "Timestamped transcript sample" is provided, key_points timestamps must use only timestamps shown in that sample.
            - If the title, description, or transcript does not provide evidence for a section, write "미확인" instead of guessing.
            - timestamp may be an empty string when transcript time evidence is unavailable.
            - key_points should prefer actionable insights over generic topic labels.
            - Do not invent details that are not grounded in the title, description, or transcript.
          RULES
        end

        private_class_method(
          :attempt_backend,
          :resolve_backends,
          :extract_result_from,
          :strip_json_fences,
          :validate_required_keys!,
          :system_prompt,
          :youtube_prompt_rules
        )
      end
    end
  end
end
