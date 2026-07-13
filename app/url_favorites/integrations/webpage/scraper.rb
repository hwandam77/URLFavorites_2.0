require "nokogiri"

module UrlFavorites
  module Integrations
    module Webpage
      class Scraper
        class FetchError < StandardError; end

        JINA_BASE_URL = "https://r.jina.ai/"
        CLOUDFLARE_SIGNATURE = "Just a moment...".freeze

        def self.call(url)
          response = Faraday.new(request: { timeout: 30, open_timeout: 10 }).get(url)

          # Cloudflare는 403 또는 200+챌린지 페이지로 차단 → Jina fallback
          if cloudflare_blocked?(response)
            return fetch_via_jina(url)
          end

          raise FetchError, "HTTP error: #{response.status}" if response.status >= 400

          doc = Nokogiri::HTML(response.body)

          {
            title: extract_title(doc),
            description: extract_description(doc),
            og_image: extract_og_image(doc),
            body_text: extract_body_text(doc)
          }
        rescue Faraday::Error => e
          raise FetchError, "Network error: #{e.message}"
        end

        def self.cloudflare_blocked?(response)
          return true if response.status == 403 && response.body.include?("cloudflare")
          return true if response.body.include?(CLOUDFLARE_SIGNATURE)
          false
        end

        def self.fetch_via_jina(url)
          jina_url = "#{JINA_BASE_URL}#{url}"
          response = Faraday.new(request: { timeout: 30, open_timeout: 10 }).get(jina_url)

          raise FetchError, "Jina HTTP error: #{response.status}" if response.status >= 400

          parse_jina_response(response.body)
        rescue Faraday::Error => e
          raise FetchError, "Jina network error: #{e.message}"
        end

        def self.parse_jina_response(body)
          title = body.match(/^Title:\s*([^\n]+)/)&.captures&.first&.strip || ""
          # Markdown Content 이후 텍스트를 body_text로 사용
          content_after_marker = body.split(/^Markdown Content:\s*\n/, 2).last || body
          body_text = content_after_marker.gsub(/\s+/, " ").strip[0...8_000]

          {
            title: title,
            description: "",
            og_image: nil,
            body_text: body_text
          }
        end

        def self.extract_title(doc)
          # GitHub pages: <h1 class="heading-element" tabindex="-1">
          if doc.at_css("h1.heading-element")
            doc.at_css("h1.heading-element")&.text&.strip.presence
          end ||
          doc.at_css("meta[property='og:title']")&.[]("content") ||
            doc.at_css("title")&.text&.strip ||
            ""
        end

        def self.extract_description(doc)
          doc.at_css("meta[property='og:description']")&.[]("content") ||
            doc.at_css("meta[name='description']")&.[]("content") ||
            ""
        end

        def self.extract_og_image(doc)
          doc.at_css("meta[property='og:image']")&.[]("content")
        end

        # article 이 광고/헤더 껍데기뿐인 사이트(tistory 등)가 있어, 본문이 충분한 첫 후보를 채택
        MIN_BODY_TEXT = 200

        def self.extract_body_text(doc)
          candidates = doc.css("article").to_a + doc.css("main").to_a + [ doc.at_css("body") ].compact
          best = ""
          candidates.each do |element|
            text = cleaned_text(element)
            return text[0...8_000] if text.length >= MIN_BODY_TEXT
            best = text if text.length > best.length
          end
          best[0...8_000]
        end

        def self.cleaned_text(element)
          clone = element.dup
          clone.css("script, style, noscript").each(&:remove)
          clone.text.gsub(/\s+/, " ").strip
        end
      end
    end
  end
end
