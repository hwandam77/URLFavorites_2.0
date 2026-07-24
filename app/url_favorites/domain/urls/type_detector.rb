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

        TWITTER_PATTERNS = [
          /\Ahttps?:\/\/(?:www\.)?x\.com(?:\/|\z)/i,
          /\Ahttps?:\/\/(?:www\.|mobile\.)?twitter\.com(?:\/|\z)/i
        ].freeze

        # 게시물 URL만 매칭 — 서브레딧 홈 등은 rdt read가 처리할 수 없어 webpage 유지
        REDDIT_PATTERNS = [
          %r{\Ahttps?://(?:www\.|old\.|new\.)?reddit\.com/r/[^/]+/comments/[^/]+}i,
          %r{\Ahttps?://redd\.it/[^/]+}i
        ].freeze

        def self.call(url)
          return "webpage" unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)
          return "youtube" if YOUTUBE_PATTERNS.any? { |pattern| url.match?(pattern) }
          return "github" if GITHUB_PATTERNS.any? { |pattern| url.match?(pattern) }
          return "twitter" if TWITTER_PATTERNS.any? { |pattern| url.match?(pattern) }
          return "reddit" if REDDIT_PATTERNS.any? { |pattern| url.match?(pattern) }
          "webpage"
        end
      end
    end
  end
end
