module UrlFavorites
  module Domain
    module Urls
      class TypeDetector
        YOUTUBE_PATTERNS = [
          /\Ahttps?:\/\/(www\.)?youtube\.com\/(watch|shorts|embed|v|playlist)/i,
          /\Ahttps?:\/\/(www\.)?youtube\.com\/(@|channel|c)\//i,
          /\Ahttps?:\/\/youtu\.be\//i
        ].freeze

        GITHUB_PATTERNS = [
          /\Ahttps?:\/\/(www\.)?github\.com\//i
        ].freeze

        def self.call(url)
          return "webpage" unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)
          return "youtube" if YOUTUBE_PATTERNS.any? { |pattern| url.match?(pattern) }
          return "github" if GITHUB_PATTERNS.any? { |pattern| url.match?(pattern) }
          "webpage"
        end
      end
    end
  end
end
