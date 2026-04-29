require "open3"
require "json"
require "shellwords"

module UrlFavorites
  module Integrations
    module Youtube
      class Extractor
        class ExtractionError < StandardError; end

        def self.call(url)
          command = "yt-dlp --dump-json #{Shellwords.escape(url)}"
          stdout, _stderr, status = Open3.capture3(command)

          raise ExtractionError, "yt-dlp failed" unless status.success?
          raise ExtractionError, "yt-dlp output is empty" if stdout.strip.empty?

          data = JSON.parse(stdout)

          title         = data["title"].to_s
          description   = data["description"].to_s
          thumbnail_url = data["thumbnail"].to_s.presence
          transcript_result = extract_transcript(data)
          transcript    = transcript_result[:text][0...12_000]
          subtitle_source = transcript_result[:source]
          transcript_segments = transcript_result[:segments]
          github_links = UrlFavorites::Domain::Content::GithubLinkExtractor.call(description, transcript)

          { title: title, description: description, transcript: transcript,
            thumbnail_url: thumbnail_url, subtitle_source: subtitle_source,
            transcript_segments: transcript_segments, github_links: github_links }
        rescue JSON::ParserError => e
          raise ExtractionError, "JSON parse failed: #{e.message}"
        end

        def self.extract_transcript(data)
          subtitles   = data["subtitles"] || {}
          auto_caps   = data["automatic_captions"] || {}

          # 1순위: 수동 자막 (ko, en 순)
          result = captions_result(subtitles, "ko") ||
                   captions_result(subtitles, "en") ||
                   captions_result(subtitles, subtitles.keys.first)
          return result.merge(source: "manual") if result

          # 2순위: 자동 자막 (ko, en 순)
          result = captions_result(auto_caps, "ko") ||
                   captions_result(auto_caps, "en") ||
                   captions_result(auto_caps, auto_caps.keys.first)
          return result.merge(source: "auto") if result

          # 3순위: description fallback
          { text: data["description"].to_s, source: "description", segments: [] }
        end

        def self.captions_text(captions_hash, lang_key)
          captions_result(captions_hash, lang_key)&.dig(:text)
        end

        def self.captions_result(captions_hash, lang_key)
          return nil unless lang_key && captions_hash.key?(lang_key)

          items = captions_hash[lang_key]
          return nil unless items.is_a?(Array) && !items.empty?

          segments = caption_segments(items)
          text = segments.map { |segment| segment[:text] }.join(" ").strip.presence
          return nil unless text

          { text: text, segments: segments }
        end

        def self.caption_segments(items)
          items.filter_map do |item|
            text = item["text"].to_s.strip
            next if text.blank?

            start = numeric_or_nil(item["start"])
            duration = numeric_or_nil(item["duration"])

            {
              start: start || 0.0,
              duration: duration || 0.0,
              timestamp: format_timestamp(start || 0.0),
              text: text
            }
          end
        end

        def self.numeric_or_nil(value)
          return nil if value.nil?

          Float(value)
        rescue ArgumentError, TypeError
          nil
        end

        def self.format_timestamp(seconds)
          total_seconds = seconds.to_i
          hours = total_seconds / 3600
          minutes = (total_seconds % 3600) / 60
          secs = total_seconds % 60

          if hours.positive?
            format("%d:%02d:%02d", hours, minutes, secs)
          else
            format("%02d:%02d", minutes, secs)
          end
        end
      end
    end
  end
end
