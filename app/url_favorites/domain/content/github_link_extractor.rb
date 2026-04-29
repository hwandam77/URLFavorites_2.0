# frozen_string_literal: true

require "uri"

module UrlFavorites
  module Domain
    module Content
      class GithubLinkExtractor
        URL_PATTERN = %r{https?://[^\s<>"']+}.freeze
        TRAILING_PUNCTUATION = /[)\].,;:!?]+\z/.freeze

        def self.call(*texts)
          texts
            .compact
            .flat_map { |text| text.to_s.scan(URL_PATTERN) }
            .map { |url| normalize(url) }
            .compact
            .select { |url| github_url?(url) }
            .uniq
        end

        def self.normalize(url)
          normalized = url.to_s.strip.sub(TRAILING_PUNCTUATION, "")
          parsed = URI.parse(normalized)
          return nil unless parsed.is_a?(URI::HTTP)
          return nil if parsed.host.blank?

          parsed.fragment = nil
          parsed.to_s
        rescue URI::InvalidURIError
          nil
        end
        private_class_method :normalize

        def self.github_url?(url)
          host = URI.parse(url).host.to_s.downcase
          host == "github.com" || host.end_with?(".github.com")
        rescue URI::InvalidURIError
          false
        end
        private_class_method :github_url?
      end
    end
  end
end
