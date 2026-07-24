require "open3"
require "json"

module UrlFavorites
  module Integrations
    module Reddit
      class Extractor
        class ExtractionError < StandardError; end

        # twitter extractor의 TRANSCRIPT_LIMIT과 동일 상한
        RAW_CONTENT_LIMIT = 12_000
        TOP_COMMENT_LIMIT = 10
        COMMENT_TEXT_LIMIT = 1_000
        STDERR_TAIL_LENGTH = 500

        def self.call(url)
          post_id = extract_post_id(url)
          raise ExtractionError, "Reddit post id not found in URL: #{url}" unless post_id

          stdout, stderr, status = Open3.capture3("rdt", "read", post_id, "--json")

          unless status.success?
            raise ExtractionError, "rdt read failed: #{stderr_tail(stderr)}"
          end
          raise ExtractionError, "rdt output is empty" if stdout.strip.empty?

          build_result(parse_json(stdout))
        rescue Errno::ENOENT
          raise ExtractionError, "rdt CLI not installed (Errno::ENOENT)"
        end

        def self.extract_post_id(url)
          url.to_s.match(%r{/comments/([a-z0-9]+)}i)&.[](1) ||
            url.to_s.match(%r{redd\.it/([a-z0-9]+)}i)&.[](1)
        end

        def self.parse_json(stdout)
          JSON.parse(stdout)
        rescue JSON::ParserError => e
          raise ExtractionError, "rdt JSON parse failed: #{e.message}"
        end

        # --json 실 출력 스키마는 미실측 — 방어적으로 키를 탐색하고
        # 예상 밖 구조(최상위가 Hash가 아닌 경우 등)에서도 예외 없이 텍스트를 활용한다.
        def self.build_result(data)
          case data
          when Hash
            title = first_string(data, "title")
            body_text = first_string(data, "selftext", "body", "text", "content")
            author = first_string(data, "author", "user", "username")
            comments = normalize_comments(data["comments"])
          when Array
            title = body_text = author = nil
            comments = normalize_comments(data)
          else
            title = author = nil
            body_text = data.to_s.presence
            comments = []
          end

          {
            title: title,
            body_text: body_text,
            author: author,
            thumbnail_url: nil,
            raw_content: raw_content(title, body_text, author, comments)
          }
        end

        def self.first_string(data, *keys)
          keys.each do |key|
            value = data[key]
            return value.to_s.presence if value.is_a?(String) && value.present?
          end
          nil
        end

        def self.normalize_comments(raw_comments)
          Array(raw_comments).filter_map do |comment|
            if comment.is_a?(Hash)
              text = first_string(comment, "body", "text", "content")
              text ? { author: first_string(comment, "author", "user", "username"), text: text } : nil
            elsif comment.is_a?(String) && comment.present?
              { author: nil, text: comment }
            end
          end.first(TOP_COMMENT_LIMIT)
        end

        def self.raw_content(title, body_text, author, comments)
          comments_text = comments.map do |comment|
            header = comment[:author].present? ? "- #{comment[:author]}: " : "- "
            "#{header}#{comment[:text][0...COMMENT_TEXT_LIMIT]}"
          end.join("\n").presence

          [
            ("Title: #{title}" if title.present?),
            ("Author: #{author}" if author.present?),
            ("Post:\n#{body_text}" if body_text.present?),
            ("Top comments:\n#{comments_text}" if comments_text.present?)
          ].compact.join("\n\n")[0...RAW_CONTENT_LIMIT]
        end

        def self.stderr_tail(stderr)
          stripped = stderr.to_s.strip
          tail = stripped.length > STDERR_TAIL_LENGTH ? stripped[-STDERR_TAIL_LENGTH..] : stripped
          tail.presence || "no stderr output"
        end

        private_class_method :extract_post_id, :parse_json, :build_result, :first_string,
                             :normalize_comments, :raw_content, :stderr_tail
      end
    end
  end
end
