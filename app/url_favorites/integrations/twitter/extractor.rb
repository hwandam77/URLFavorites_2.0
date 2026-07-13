# frozen_string_literal: true

require "json"
require "open3"

module UrlFavorites
  module Integrations
    module Twitter
      class Extractor
        class ExtractionError < StandardError; end

        VIDEO_HINT = /(?:\bvideo\b|동영상|video\.twimg\.com|ext_tw_video|amplify_video)/i
        TRANSCRIPT_LIMIT = 12_000
        SYNDICATION_URL = "https://cdn.syndication.twimg.com/tweet-result"
        SYNDICATION_TOKEN = "a"
        BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

        def self.call(url)
          content = fetch_content(url)
          result = {
            title: content[:title],
            body_text: content[:body_text],
            author: content[:author] || extract_author(content[:title], content[:body_text]),
            thumbnail_url: content[:thumbnail_url],
            is_video: content[:is_video] || video?(url, content[:body_text]),
            transcript: nil,
            subtitle_source: nil,
            transcript_segments: []
          }

          result.merge!(video_metadata(url)) if result[:is_video]
          result.merge(raw_content: raw_content(result))
        rescue UrlFavorites::Integrations::Webpage::Scraper::FetchError => e
          raise ExtractionError, e.message
        end

        def self.fetch_content(url)
          id = tweet_id(url)
          syndication = fetch_via_syndication(id) if id
          syndication || UrlFavorites::Integrations::Webpage::Scraper.fetch_via_jina(url)
        end

        def self.fetch_via_syndication(id)
          response = Faraday.new(
            request: { timeout: 30, open_timeout: 10 },
            headers: { "User-Agent" => BROWSER_USER_AGENT }
          ).get(SYNDICATION_URL, id: id, token: SYNDICATION_TOKEN, lang: "en")
          return unless response.status.between?(200, 299)

          data = JSON.parse(response.body)
          return unless data.is_a?(Hash)

          quoted_tweet = data["quoted_tweet"]
          quoted_text = quoted_tweet["text"] if quoted_tweet.is_a?(Hash)
          text = [ data["text"], quoted_text ].compact_blank.join("\n\n")
          return if text.blank?

          media_details = Array(data["mediaDetails"]).select { |media| media.is_a?(Hash) }
          user = data["user"]
          user = {} unless user.is_a?(Hash)
          author_name = user["name"].presence
          screen_name = user["screen_name"].presence
          author = if author_name && screen_name
            "#{author_name} (@#{screen_name})"
          else
            author_name || screen_name&.then { |name| "@#{name}" }
          end

          {
            title: [ author, text[0...80] ].compact_blank.join(": "),
            body_text: text[0...8_000],
            author: author.presence,
            thumbnail_url: media_details.find { |media| media["type"] == "photo" }&.values_at(
              "media_url_https", "media_url", "url"
            )&.compact_blank&.first,
            is_video: media_details.any? { |media| %w[video animated_gif].include?(media["type"]) }
          }
        rescue Faraday::Error, JSON::ParserError
          nil
        end

        def self.tweet_id(url)
          url.to_s.match(%r{/status/(\d+)})&.[](1)
        end

        def self.video?(url, body_text)
          url.to_s.match?(%r{/video(?:/|\z)}i) || body_text.to_s.match?(VIDEO_HINT)
        end

        def self.video_metadata(url)
          stdout, _stderr, status = Open3.capture3("yt-dlp", "--dump-json", url)
          return {} unless status.success? && stdout.present?

          data = JSON.parse(stdout)
          transcript = UrlFavorites::Integrations::Youtube::Extractor.extract_transcript(data)

          {
            title: data["title"].presence,
            author: (data["uploader"] || data["channel"]).to_s.presence,
            thumbnail_url: data["thumbnail"].to_s.presence,
            transcript: transcript[:text].to_s[0...TRANSCRIPT_LIMIT].presence,
            subtitle_source: transcript[:source],
            transcript_segments: transcript[:segments]
          }.compact
        rescue JSON::ParserError, SystemCallError
          {}
        end

        def self.extract_author(title, body_text)
          [ title, body_text ].filter_map do |value|
            value.to_s.match(/([^:|]{1,80})\s*\(@[^)]+\)/)&.captures&.first&.strip&.presence
          end.first
        end

        def self.raw_content(result)
          [
            ("Title: #{result[:title]}" if result[:title].present?),
            ("Author: #{result[:author]}" if result[:author].present?),
            ("Post / thread:\n#{result[:body_text]}" if result[:body_text].present?),
            ("Video transcript:\n#{result[:transcript]}" if result[:transcript].present?)
          ].compact.join("\n\n")
        end

        private_class_method :fetch_content, :fetch_via_syndication, :tweet_id,
                              :video?, :video_metadata, :extract_author, :raw_content
      end
    end
  end
end
