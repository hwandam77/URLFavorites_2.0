# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module LlamaServer
      # vLLM(및 OpenAI 호환 백엔드)의 생존 확인. GET /health — vllm은 준비되면 200.
      # 분석 파이프라인이 헬스 체크에 쓰는 만큼 짧은 타임아웃으로 장애를 빠르게 판정한다.
      class HealthCheck
        TIMEOUT_SECONDS = 5

        def self.call
          backends = UrlFavorites::Integrations::LlamaServer::Client.backends
          return false if backends.empty?

          backends.all? { |backend| backend_healthy?(backend[:url], backend[:model]) }
        end

        def self.backend_healthy?(base_url, model = nil)
          return false if base_url.blank?

          conn = Faraday.new(base_url) do |f|
            f.options.timeout = TIMEOUT_SECONDS
            f.options.open_timeout = TIMEOUT_SECONDS
          end
          response = conn.get("/health")
          return false unless response.status == 200
          return true if model.blank?

          begin
            models_response = conn.get("/v1/models")
            return true unless models_response.status == 200

            parsed = JSON.parse(models_response.body)
            data = parsed.is_a?(Hash) ? parsed["data"] : nil
            return true unless data.is_a?(Array) && data.any?

            ids = data.filter_map { |entry| entry["id"] if entry.is_a?(Hash) }
            return true if ids.empty? || ids.include?(model)

            Rails.logger.error "[LlamaServer::HealthCheck] configured model=#{model.inspect}; serving ids=#{ids.inspect}"
            false
          rescue Faraday::Error, JSON::ParserError, Errno::ECONNREFUSED
            true
          end
        rescue Faraday::Error, Errno::ECONNREFUSED => e
          Rails.logger.warn "[LlamaServer::HealthCheck] #{base_url} unhealthy: #{e.class} #{e.message}"
          false
        end
      end
    end
  end
end
