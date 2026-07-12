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

        def self.call(url)
          jina = UrlFavorites::Integrations::Webpage::Scraper.fetch_via_jina(url)
          result = {
            title: jina[:title],
            body_text: jina[:body_text],
            author: extract_author(jina[:title], jina[:body_text]),
            thumbnail_url: nil,
            is_video: video?(url, jina[:body_text]),
            transcript: nil,
            subtitle_source: nil,
            transcript_segments: []
          }

          result.merge!(video_metadata(url)) if result[:is_video]
          result.merge(raw_content: raw_content(result))
        rescue UrlFavorites::Integrations::Webpage::Scraper::FetchError => e
          raise ExtractionError, e.message
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

        private_class_method :video?, :video_metadata, :extract_author, :raw_content
      end
    end
  end
end
