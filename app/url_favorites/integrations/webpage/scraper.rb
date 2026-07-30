require "nokogiri"

module UrlFavorites
  module Integrations
    module Webpage
      class Scraper
        class FetchError < StandardError; end

        JINA_BASE_URL = "https://r.jina.ai/"
        CLOUDFLARE_SIGNATURE = "Just a moment...".freeze
        MAX_REDIRECTS = 5
        # 본문 상한: fast n_ctx 262,144 기준 20,000자 ≈ 7k 토큰 — 매뉴얼 섹션 생성의 근거 원문 확보용
        BODY_TEXT_LIMIT = 20_000

        def self.call(url)
          response, final_url = fetch_following_redirects(url)

          # Cloudflare는 403 또는 200+챌린지 페이지로 차단 → Jina fallback
          if cloudflare_blocked?(response)
            return fetch_via_jina(final_url)
          end

          raise FetchError, "HTTP error: #{response.status}" if response.status >= 300

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

        # share.google 등 단축링크는 302 체인 뒤에 실제 콘텐츠가 있다 (Faraday 는 기본 미추적)
        def self.fetch_following_redirects(url)
          MAX_REDIRECTS.times do
            response = Faraday.new(request: { timeout: 30, open_timeout: 10 }).get(url)
            location = response.headers["location"]
            return [ response, url ] unless response.status.between?(300, 399) && location.present?
            url = URI.join(url, location).to_s
          end
          raise FetchError, "Too many redirects"
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
          body_text = content_after_marker.gsub(/\s+/, " ").strip[0...BODY_TEXT_LIMIT]

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
            return text[0...BODY_TEXT_LIMIT] if text.length >= MIN_BODY_TEXT
            best = text if text.length > best.length
          end
          best[0...BODY_TEXT_LIMIT]
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
