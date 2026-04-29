require "nokogiri"

module UrlFavorites
  module Integrations
    module Webpage
      class Scraper
        class FetchError < StandardError; end

        def self.call(url)
          response = Faraday.new(request: { timeout: 30, open_timeout: 10 }).get(url)

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

        def self.extract_body_text(doc)
          element = doc.at_css("article") || doc.at_css("main") || doc.at_css("body")
          return "" unless element

          clone = element.dup
          clone.css("script, style, noscript").each(&:remove)
          text = clone.text.gsub(/\s+/, " ").strip
          text[0...8_000]
        end
      end
    end
  end
end
