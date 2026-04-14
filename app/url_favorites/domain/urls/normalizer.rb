require "uri"

module UrlFavorites
  module Domain
    module Urls
      class Normalizer
        def self.call(url)
          raise ArgumentError, "URL cannot be nil" if url.nil?
          raise ArgumentError, "URL cannot be empty" if url.strip.empty?

          # https:// 스키마가 누락된 경우 추가
          normalized = url.strip
          normalized = "https://#{normalized}" unless normalized.match?(/\Ahttps?:\/\//i)

          uri = URI.parse(normalized)

          # 스키마와 호스트를 소문자로 정규화
          uri.scheme = uri.scheme.downcase
          uri.host = uri.host.downcase

          # 끝 슬래시 제거 (루트 경로만)
          uri.path = "" if uri.path == "/"

          # UTM 매개변수 제거하지만 다른 쿼리 매개변수는 유지
          if uri.query
            params = URI.decode_www_form(uri.query).reject { |k, _| k.start_with?("utm_") }
            uri.query = params.empty? ? nil : URI.encode_www_form(params)
          end

          uri.fragment = nil
          uri.to_s
        end
      end
    end
  end
end
