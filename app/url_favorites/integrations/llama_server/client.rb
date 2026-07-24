# frozen_string_literal: true

require Rails.root.join("app/url_favorites/domain/analysis").to_s
require Rails.root.join("app/url_favorites/domain/analysis/backend_router").to_s
require Rails.root.join("app/url_favorites/domain/analysis/prompt_style").to_s

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

        def self.call(content, type:, analysis_style: UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT, content_length: nil, backend_role: nil)
          normalized_style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)
          backends = prioritize_backends(
            resolve_backends,
            content_type: type,
            content_length: content_length || content.to_s.length,
            analysis_style: analysis_style,
            backend_role: backend_role
          )

          last_error = nil
          backends.each do |backend|
            result = attempt_backend(backend, content, type, normalized_style)
            return result if result
          rescue ServerError, ParseError => e
            last_error = e
            Rails.logger.warn "[LlamaServer::Client] Backend #{backend[:url]} failed: #{e.message}"
          end

          raise ServerError, "All LLM backends failed. Last error: #{last_error&.message}"
        end

        def self.attempt_backend(backend, content, type, analysis_style)
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
              { role: "system", content: [ system_prompt(type, analysis_style), style_prompt(analysis_style) ].join("\n\n") },
              { role: "user", content: "#{type}: #{content}" }
            ],
            response_format: { type: "json_object" }
          }

          response = conn.post("/v1/chat/completions", body)

          parsed = parse_json_object(response.body)
          inner = extract_result_from(parsed)
          validate_required_keys!(inner)

          result = inner.slice(:summary, :key_points, :tags, :sentiment)
          result[:detail_content] = inner[:detail_content] if inner.key?(:detail_content)
          result[:used_backend_role] = backend[:role].to_s
          result[:used_backend_model] = model
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

        def self.prioritize_backends(backends, content_type:, content_length:, analysis_style:, backend_role: nil)
          priorities = if backend_role.present?
            role = backend_role.to_s
            [ role ] + (%w[fast heavy] - [ role ])
          else
            UrlFavorites::Domain::Analysis::BackendRouter.call(
              content_type: content_type,
              content_length: content_length,
              analysis_style: analysis_style
            )
          end
          prioritized = priorities.flat_map do |role|
            backends.select { |backend| backend[:role].to_s == role }
          end

          prioritized.empty? ? backends : prioritized + (backends - prioritized)
        rescue StandardError => e
          Rails.logger.warn "[LlamaServer::Client] Backend routing failed: #{e.message}"
          backends
        end

        def self.extract_result_from(parsed)
          if parsed.is_a?(Hash) && parsed.key?(:choices)
            message_content = parsed.dig(:choices, 0, :message, :content)
            raise ParseError, "Missing message.content in response" if message_content.blank?

            json = strip_json_fences(message_content)
            parse_json_object(json)
          else
            parsed
          end
        end

        def self.parse_json_object(text)
          JSON.parse(text, symbolize_names: true)
        rescue JSON::ParserError
          JSON.parse(escape_control_chars_in_strings(text), symbolize_names: true)
        end

        def self.escape_control_chars_in_strings(text)
          in_string = false
          escaped = false

          text.each_char.with_object(+"") do |char, output|
            if escaped
              output << char
              escaped = false
              next
            end

            if char == "\\"
              output << char
              escaped = true
              next
            end

            if char == '"'
              in_string = !in_string
              output << char
              next
            end

            if in_string && char.ord < 0x20
              output << case char
              when "\n" then "\\n"
              when "\r" then "\\r"
              when "\t" then "\\t"
              else "\\u%04x" % char.ord
              end
              next
            end

            output << char
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

        def self.system_prompt(type = nil, analysis_style = UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT)
          normalized_style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)

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
            - detail_content: 전체 핵심 내용을 3~5문단으로 작성한다. 원문이 어떤 언어이든 detail_content 는 반드시 한국어로 서술한다.
            - Escape all line breaks inside JSON string values as \\n. Do not insert literal newline characters inside quoted JSON strings.
            #{youtube_prompt_rules(normalized_style) if type == "youtube"}
            #{twitter_prompt_rules if type == "twitter"}
          PROMPT
        end

        def self.twitter_prompt_rules
          <<~RULES

            For X (Twitter) content:
            - Identify the author's central claim and the evidence supporting it.
            - Reconstruct the thread structure and explain how consecutive posts develop the argument.
            - Extract quoted claims and external links or resources without inventing missing details.
            - Preserve the author identity and the context needed to interpret the post.
            - Distinguish the author's statements from replies, quotations, and your own inference.
          RULES
        end

        def self.youtube_prompt_rules(analysis_style)
          <<~RULES

            For YouTube content:
            - Treat the video as source material for a professional AI analysis artifact, not a casual summary.
            #{youtube_detail_content_rules(analysis_style)}
            - In "## 영상에서 제공한 GitHub 링크", preserve only GitHub URLs explicitly present in "Provided GitHub links"; copy each URL exactly as a markdown bullet.
            - If "Provided GitHub links" is "미확인" or empty, write "미확인" in that section.
            - When the selected style is not execution_brief, do not use the execution_brief section order.
            - If a ready-to-use prompt section is requested, it must explicitly include 역할, 작업, 입력, and 출력 형식.
            - When "Timestamped transcript sample" is provided, key_points timestamps must use only timestamps shown in that sample.
            - If the title, description, or transcript does not provide evidence for a section, write "미확인" instead of guessing.
            - timestamp may be an empty string when transcript time evidence is unavailable.
            - key_points should prefer actionable insights over generic topic labels.
            - Do not invent details that are not grounded in the title, description, or transcript.
          RULES
        end

        def self.youtube_detail_content_rules(analysis_style)
          case analysis_style
          when "qna"
            <<~RULES
              - detail_content must be a Korean markdown Q&A document.
              - detail_content must start with exactly: ## 기본 질문
              - Use these exact section headings in this order:
                ## 기본 질문
                ## 심화 질문
                ## 흔한 오해
                ## 후속 탐구 주제
                ## 영상에서 제공한 GitHub 링크
              - Include exactly three basic questions, two advanced questions, one common misconception, and follow-up topics.
            RULES
          when "tutorial"
            <<~RULES
              - detail_content must be a Korean markdown step-by-step tutorial.
              - detail_content must start with exactly: ## 준비물
              - Use these exact section headings in this order:
                ## 준비물
                ## 단계별 실행
                ## 기대 결과
                ## 검증 체크
                ## 자주 막히는 지점
                ## 영상에서 제공한 GitHub 링크
              - Steps must be concrete actions a human can perform manually.
            RULES
          when "prompt_extract"
            <<~RULES
              - detail_content must be reusable AI instructions only.
              - detail_content must start with exactly: ## 바로 복사할 프롬프트
              - Use these exact section headings in this order:
                ## 바로 복사할 프롬프트
                ## 역할
                ## 작업
                ## 입력 형식
                ## 출력 형식
                ## 제약 조건
                ## 검증 체크리스트
                ## 영상에서 제공한 GitHub 링크
              - The prompt must be directly copyable into another AI session.
            RULES
          else
            <<~RULES
              - detail_content must be a Korean markdown document with these exact section headings:
                ## 콘텐츠의 목적과 핵심 주장
                ## 영상에서 제공한 GitHub 링크
                ## 실행 가능한 절차
                ## 바로 사용 가능한 AI 프롬프트
                ## 필요한 입력값, 전제 조건, 주의할 리스크
                ## 추가로 확인하면 좋은 질문
              - In "## 실행 가능한 절차", write steps a human can perform manually.
              - In "## 바로 사용 가능한 AI 프롬프트", write one complete ready-to-use prompt that another AI can execute immediately.
              - The purpose of "## 바로 사용 가능한 AI 프롬프트" is to help the user reuse the video's method on their own input or task.
            RULES
          end
        end

        def self.style_prompt(analysis_style)
          normalized_style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)
          <<~PROMPT
            Analysis style: #{normalized_style}
            The selected analysis style is mandatory. The detail_content structure must visibly match this style.
            #{UrlFavorites::Domain::Analysis::PromptStyle.instructions_for(normalized_style)}
          PROMPT
        end

        private_class_method(
          :attempt_backend,
          :resolve_backends,
          :prioritize_backends,
          :extract_result_from,
          :parse_json_object,
          :escape_control_chars_in_strings,
          :strip_json_fences,
          :validate_required_keys!,
          :system_prompt,
          :twitter_prompt_rules,
          :youtube_prompt_rules,
          :youtube_detail_content_rules,
          :style_prompt
        )
      end
    end
  end
end
