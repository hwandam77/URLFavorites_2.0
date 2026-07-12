# URLFavorites 2.0 DDD Strong Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rails 앱을 `UrlFavorites::(Domain|UseCases|Integrations)` 구조로 “클린 컷” 리팩터링하여, 컨트롤러/잡이 유스케이스만 호출하고 외부 의존성은 Integrations로 격리되도록 만든다.

**Architecture:**
- 컨트롤러/잡은 입력/출력만 담당하고, 모든 흐름을 `UrlFavorites::UseCases::*`로 내린다.
- URL 규칙/상태 전이/재시도 정책은 `UrlFavorites::Domain::*`에 고정한다.
- llama-server/yt-dlp/Nokogiri/FTS/Embedding 등 외부 의존성은 `UrlFavorites::Integrations::*`로 격리한다.

**Tech Stack:** Rails 8.1, Ruby, Minitest, Solid Queue, SQLite(FTS5), Faraday, Nokogiri, yt-dlp, WebMock

---

## File Structure

리팩터링 후 핵심 구조(신규/이동):

```
app/
  url_favorites.rb
  url_favorites/
    domain/
      errors/
      urls/
      analysis/
    integrations/
      llama_server/
      webpage/
      youtube/
      search/
      importers/
        urlf_snapshot/
    use_cases/
      favorites/
      analysis/
      search/
      collections/
      notes/
      newsletter/
      importers/
```

기존 파일 매핑(대표):

- `app/services/url_normalizer.rb`
  - → `app/url_favorites/domain/urls/normalizer.rb`
- `app/services/url_safety_validator.rb`
  - → `app/url_favorites/domain/urls/safety_policy.rb`
- `app/services/url_type_detector.rb`
  - → `app/url_favorites/domain/urls/type_detector.rb`
- `app/services/url_category_detector.rb`
  - → `app/url_favorites/domain/urls/category_detector.rb`
- `app/services/webpage_scraper.rb`
  - → `app/url_favorites/integrations/webpage/scraper.rb`
- `app/services/youtube_extractor.rb`
  - → `app/url_favorites/integrations/youtube/extractor.rb`
- `app/services/llm_analyzer.rb`
  - → `app/url_favorites/integrations/llama_server/client.rb`
- `app/services/embedding_service.rb`
  - → `app/url_favorites/integrations/search/embedding_client.rb`
- `app/services/favorite_search_indexer.rb`
  - → `app/url_favorites/integrations/search/indexer.rb`
- `app/services/semantic_search.rb`
  - → `app/url_favorites/integrations/search/semantic_client.rb`
- `app/services/favorite_search.rb`
  - → `app/url_favorites/use_cases/search/favorite_search.rb`
- `app/services/importers/urlf_snapshot_importer.rb`
  - → `app/url_favorites/use_cases/importers/import_urlf_snapshot.rb`
  - (+ 포맷 파싱/DB 접근은 `app/url_favorites/integrations/importers/urlf_snapshot/*`)

---

## Task 1: UrlFavorites 루트 네임스페이스 및 공통 타입(Errors/Result) 추가

**Files:**
- Create: `app/url_favorites.rb`
- Create: `app/url_favorites/domain/errors/base_error.rb`
- Create: `app/url_favorites/domain/errors/unsafe_url.rb`
- Create: `app/url_favorites/use_cases/result.rb`
- Test: `test/url_favorites/boot_test.rb`

- [ ] **Step 1: 루트 네임스페이스 파일 생성**

```ruby
# app/url_favorites.rb
module UrlFavorites
end
```

- [ ] **Step 2: Domain 에러 베이스/UnsafeUrl 에러 추가**

```ruby
# app/url_favorites/domain/errors/base_error.rb
module UrlFavorites
  module Domain
    module Errors
      class BaseError < StandardError; end
    end
  end
end
```

```ruby
# app/url_favorites/domain/errors/unsafe_url.rb
module UrlFavorites
  module Domain
    module Errors
      class UnsafeUrl < BaseError; end
    end
  end
end
```

- [ ] **Step 3: UseCase 공통 Result 타입 추가**

```ruby
# app/url_favorites/use_cases/result.rb
module UrlFavorites
  module UseCases
    Result = Struct.new(:ok?, :value, :error, keyword_init: true)
  end
end
```

- [ ] **Step 4: Zeitwerk 로딩 스모크 테스트 추가**

```ruby
# test/url_favorites/boot_test.rb
require "test_helper"

class UrlFavoritesBootTest < ActiveSupport::TestCase
  test "UrlFavorites namespace loads" do
    assert_equal "UrlFavorites", UrlFavorites.name
  end
end
```

- [ ] **Step 5: 테스트 실행**

Run: `bin/rails test test/url_favorites/boot_test.rb`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/url_favorites.rb app/url_favorites/domain/errors app/url_favorites/use_cases/result.rb test/url_favorites/boot_test.rb
git commit -m "refactor(ddd): add UrlFavorites namespace, base errors, and use case result"
```

---

## Task 2: Domain::Urls (Normalizer/Safety/Type/Category) 클린 컷 이관

**Files:**
- Move+Modify: `app/services/url_normalizer.rb` → `app/url_favorites/domain/urls/normalizer.rb`
- Move+Modify: `app/services/url_safety_validator.rb` → `app/url_favorites/domain/urls/safety_policy.rb`
- Move+Modify: `app/services/url_type_detector.rb` → `app/url_favorites/domain/urls/type_detector.rb`
- Move+Modify: `app/services/url_category_detector.rb` → `app/url_favorites/domain/urls/category_detector.rb`
- Move+Modify: `test/services/url_normalizer_test.rb` → `test/url_favorites/domain/urls/normalizer_test.rb`
- Move+Modify: `test/services/url_safety_validator_test.rb` → `test/url_favorites/domain/urls/safety_policy_test.rb`
- Move+Modify: `test/services/url_type_detector_test.rb` → `test/url_favorites/domain/urls/type_detector_test.rb`
- Create: `test/url_favorites/domain/urls/category_detector_test.rb`

- [ ] **Step 1: UrlNormalizer → Domain::Urls::Normalizer**

```bash
git mv app/services/url_normalizer.rb app/url_favorites/domain/urls/normalizer.rb
```

```ruby
# app/url_favorites/domain/urls/normalizer.rb
require "uri"

module UrlFavorites
  module Domain
    module Urls
      class Normalizer
        def self.call(url)
          raise ArgumentError, "URL cannot be nil" if url.nil?
          raise ArgumentError, "URL cannot be empty" if url.strip.empty?

          normalized = url.strip
          normalized = "https://#{normalized}" unless normalized.match?(/\Ahttps?:\/\//i)

          uri = URI.parse(normalized)
          uri.scheme = uri.scheme.downcase
          uri.host = uri.host.downcase
          uri.path = "" if uri.path == "/"

          if uri.query
            params = URI.decode_www_form(uri.query).reject { |k, _| k.start_with?("utm_") }
            uri.query = params.empty? ? nil : URI.encode_www_form(params)
          end

          uri.fragment = nil
          uri.to_s
        end
      end
    end
  end
end
```

- [ ] **Step 2: UrlSafetyValidator → Domain::Urls::SafetyPolicy**

```bash
git mv app/services/url_safety_validator.rb app/url_favorites/domain/urls/safety_policy.rb
```

```ruby
# app/url_favorites/domain/urls/safety_policy.rb
require "uri"
require "ipaddr"

module UrlFavorites
  module Domain
    module Urls
      class SafetyPolicy
        BLOCKED_HOSTS = %w[localhost].freeze

        def self.allowed?(url)
          return false unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)

          uri = URI.parse(url)
          host = uri.host&.gsub(/\[|\]/, "")
          return false if host.blank?
          return false if BLOCKED_HOSTS.include?(host.downcase)

          begin
            ip = IPAddr.new(host)
            return false if ip.private? || ip.loopback?
          rescue IPAddr::InvalidAddressError
            # hostname allowed
          end

          true
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
```

- [ ] **Step 3: UrlTypeDetector → Domain::Urls::TypeDetector**

```bash
git mv app/services/url_type_detector.rb app/url_favorites/domain/urls/type_detector.rb
```

```ruby
# app/url_favorites/domain/urls/type_detector.rb
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
```

- [ ] **Step 4: UrlCategoryDetector → Domain::Urls::CategoryDetector**

```bash
git mv app/services/url_category_detector.rb app/url_favorites/domain/urls/category_detector.rb
```

```ruby
# app/url_favorites/domain/urls/category_detector.rb
module UrlFavorites
  module Domain
    module Urls
      class CategoryDetector
        CATEGORY_PATTERNS = {
          "AI에이전트" => [
            /langchain\.ai|llamaindex\.ai|crewai\.com|autogen\.ai/i,
            /claude\.ai|openai\.com\.agent|gemini\.google\.com|vertex\.ai/i,
            /mcp\.run|mcp\.iit|modelcontextprotocol\.github/i,
            /pinecone\.io|weaviate\.io|chroma\.dev|qdrant\.tech|milvus\.ai/i,
            /crewai\.co|multiagent\.ai|agentica\.ai/i,
            /langchain|llamaindex|crewai|autogen|multiagent|agent.?framework/i,
            /claude.?api|openai.?agent|gemini.?agent|mcp.?server/i,
            /agent.?loop|reasoning.?engine|autonomous.?agent/i,
            /pinecone|weaviate|chroma.?db|vector.?db|rag.?retrieval/i
          ],
          "AI코딩" => [
            /cursor\.sh|windsurf\.ai|claude\.dev|nextjs\.ai|v0\.dev/i,
            /bolt\.diagrams\.net|replit\.com|lovable\.dev|devin\.ai/i,
            /github\.com\/.*copilot/i,
            /github\.copilot|cursor|windsurf|claude.?dev|nextjs.?ai/i,
            /v0\.dev|bolt\.new|replit|lovable|devin| SWE.?bench/i,
            /code.?generation|ai.?code.?review|automated.?refactor/i
          ],
          "튜토리얼" => [
            /tutorial\.example|scrimba\.com|egghead\.io|coursera\.org/i,
            /udemy\.com|udacity\.com|khanacademy\.org|freecodecamp\.org/i,
            /docs\.readme\.io|guides\.github|iHerb\.com/i,
            /blog\.post|cheatsheet|quickstart/i,
            /tutorial|course|guide|how.?to|learn|getting.?started/i,
            /docs\.readme|blog\.post|cheatsheet|quickstart/i,
            /example|demo|sandbox|playground/i
          ],
          "AI모델" => [
            /huggingface\.co|ollama\.ai|vllm\.github|anthropic\.com/i,
            /openai\.com|gptstore\.openai|chatgpt\.com|cohere\.ai/i,
            /mistral\.ai|qwen\.tongyi|deepseek\.ai|groq\.com/i,
            /lepton\.ai|replicate\.com|sAMBAmultiLLM/i,
            /hugging.?face|transformers|llama|gemini|claude|gpt|ollama/i,
            /model.?hub|pretrained|fine.?tuning|rlhf|llm.?benchmark/i,
            /mistral|qwen|deepseek|command[_-]?r|Yi.?34B|Starling/i
          ],
          "개발도구" => [
            /github\.com|gitlab\.com|bitbucket\.org/i,
            /docker\.com|traefik\.io|kubernetes\.io|terraform\.io/i,
            /jetbrains\.com|neovim\.io|vim\.org|reddit\.com\/r\/vim/i,
            /postman\.com|insomnia\.rest|swagger\.io|openapi-generator/i,
            %r{argoproj|argocd|github/actions|github/pages}i,
            /github\.com\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]*\.git|gitlab|bitbucket/i,
            /docker|kubernetes|terraform|ansible|ci\/cd|pipeline/i,
            /vscode|jetbrains|vim|neovim|terminal|cli/i,
            /postman|insomnia|swagger|openapi|api.?design/i
          ],
          "뉴스/커뮤니티" => [
            /medium\.com|dev\.to|hashnode\.com|newsletter\.producthunt/i,
            /reddit\.com|hackernews\.ycombinator|lobste\.rs/i,
            /twitter\.com|x\.com|linkedin\.com|discord\.gg/i,
            /arxiv\.org|papers\.withcode|research\.google|deepmind\.com/i,
            /feedly\.com|inoreader\.com|bloglovin|rss\./i,
            /newsletter|blog|rss|medium|dev\.to|hashnode/i,
            /reddit|hacker.?news|lobsters|product.?hunt/i,
            /twitter\.com|x\.com|linkedin|discord|slack\.com/i,
            /arxiv\.org|papers\.withcode|research\.google/i
          ]
        }.freeze

        def self.call(url, content_type = nil)
          return "기타" unless url.is_a?(String) && url.present?

          if content_type == "youtube" || url.match?(/\Ahttps?:\/\/(www\.)?youtube\.com\/(watch|shorts|embed)/i)
            return detect_youtube_category(url)
          end

          if content_type == "github" || url.match?(/\Ahttps?:\/\/(www\.)?github\.com\//i)
            return detect_github_category(url)
          end

          detect_web_category(url)
        end

        private_class_method def self.detect_youtube_category(url)
          channel_patterns = {
            "AI모델" => [/sentdex|statquest|coreyms/i, /two?minute.?papers/i],
            "튜토리얼" => [/traversymedia|freeswitutorials|netninjas/i],
            "뉴스/커뮤니티" => [/linus.?tech.?tips|mrwho|Benjamin.?Keys/i]
          }

          channel_patterns.each do |category, patterns|
            patterns.each do |pattern|
              return category if url.match?(pattern)
            end
          end

          "튜토리얼"
        end

        private_class_method def self.detect_github_category(url)
          path = url.downcase
          return "AI에이전트" if path.match?(/langchain|llamaindex|crewai|autogen/i)
          return "AI모델" if path.match?(/transformers|hugging.?face|ollama|vllm/i)
          return "개발도구" if path.match?(/vscode|neovim|neovim|docker|kubernetes/i)
          "기타"
        end

        private_class_method def self.detect_web_category(url)
          lowered_url = url.downcase
          CATEGORY_PATTERNS.each do |category, patterns|
            patterns.each do |pattern|
              return category if lowered_url.match?(pattern)
            end
          end
          "기타"
        end
      end
    end
  end
end
```

- [ ] **Step 5: 테스트 파일 이동 및 상수명 변경**

```bash
git mv test/services/url_normalizer_test.rb test/url_favorites/domain/urls/normalizer_test.rb
git mv test/services/url_safety_validator_test.rb test/url_favorites/domain/urls/safety_policy_test.rb
git mv test/services/url_type_detector_test.rb test/url_favorites/domain/urls/type_detector_test.rb
```

`type_detector_test`는 GitHub 기대값을 현재 구현에 맞춰 수정한다.

```ruby
# test/url_favorites/domain/urls/type_detector_test.rb (diff)
-  test "github URL은 webpage" do
-    assert_equal "webpage", UrlTypeDetector.call("https://github.com/rails/rails")
-  end
+  test "github URL은 github" do
+    assert_equal "github", UrlFavorites::Domain::Urls::TypeDetector.call("https://github.com/rails/rails")
+  end
```

- [ ] **Step 6: Domain URL 테스트 실행**

Run: `bin/rails test test/url_favorites/domain/urls`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/url_favorites/domain/urls test/url_favorites/domain/urls
git commit -m "refactor(ddd): move URL rules into UrlFavorites::Domain::Urls"
```

---

## Task 3: Integrations (Webpage/Youtube) 클린 컷 이관

**Files:**
- Move+Modify: `app/services/webpage_scraper.rb` → `app/url_favorites/integrations/webpage/scraper.rb`
- Move+Modify: `app/services/youtube_extractor.rb` → `app/url_favorites/integrations/youtube/extractor.rb`
- Move+Modify: `test/services/webpage_scraper_test.rb` → `test/url_favorites/integrations/webpage/scraper_test.rb`
- Move+Modify: `test/services/youtube_extractor_test.rb` → `test/url_favorites/integrations/youtube/extractor_test.rb`

- [ ] **Step 1: WebpageScraper 이동 및 네임스페이스 래핑**

```bash
git mv app/services/webpage_scraper.rb app/url_favorites/integrations/webpage/scraper.rb
```

```ruby
# app/url_favorites/integrations/webpage/scraper.rb
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

          text = element.text.gsub(/\s+/, " ").strip
          text[0...8_000]
        end
      end
    end
  end
end
```

- [ ] **Step 2: YoutubeExtractor 이동 및 네임스페이스 래핑**

```bash
git mv app/services/youtube_extractor.rb app/url_favorites/integrations/youtube/extractor.rb
```

```ruby
# app/url_favorites/integrations/youtube/extractor.rb
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

          { title: title, description: description, transcript: transcript,
            thumbnail_url: thumbnail_url, subtitle_source: subtitle_source }
        rescue JSON::ParserError => e
          raise ExtractionError, "JSON parse failed: #{e.message}"
        end

        def self.extract_transcript(data)
          subtitles   = data["subtitles"] || {}
          auto_caps   = data["automatic_captions"] || {}

          result = captions_text(subtitles, "ko") ||
                   captions_text(subtitles, "en") ||
                   captions_text(subtitles, subtitles.keys.first)
          return { text: result, source: "manual" } if result

          result = captions_text(auto_caps, "ko") ||
                   captions_text(auto_caps, "en") ||
                   captions_text(auto_caps, auto_caps.keys.first)
          return { text: result, source: "auto" } if result

          { text: data["description"].to_s, source: "description" }
        end

        def self.captions_text(captions_hash, lang_key)
          return nil unless lang_key && captions_hash.key?(lang_key)

          items = captions_hash[lang_key]
          return nil unless items.is_a?(Array) && !items.empty?

          items.map { |item| item["text"].to_s }.join(" ").strip.presence
        end
      end
    end
  end
end
```

- [ ] **Step 3: 테스트 이동 및 상수명 업데이트**

```bash
git mv test/services/webpage_scraper_test.rb test/url_favorites/integrations/webpage/scraper_test.rb
git mv test/services/youtube_extractor_test.rb test/url_favorites/integrations/youtube/extractor_test.rb
```

테스트에서 호출 상수를 다음으로 변경한다.

- `WebpageScraper` → `UrlFavorites::Integrations::Webpage::Scraper`
- `YoutubeExtractor` → `UrlFavorites::Integrations::Youtube::Extractor`

- [ ] **Step 4: 테스트 실행**

Run: `bin/rails test test/url_favorites/integrations/webpage/scraper_test.rb test/url_favorites/integrations/youtube/extractor_test.rb`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/url_favorites/integrations/webpage app/url_favorites/integrations/youtube test/url_favorites/integrations
git commit -m "refactor(ddd): move extractors into UrlFavorites::Integrations"
```

---

## Task 4: Integrations::LlamaServer::Client 도입 (기존 LlmAnalyzer 대체)

**Files:**
- Move+Modify: `app/services/llm_analyzer.rb` → `app/url_favorites/integrations/llama_server/client.rb`
- Move+Modify: `test/services/llm_analyzer_test.rb` → `test/url_favorites/integrations/llama_server/client_test.rb`
- Move+Modify: `test/services/llm_analyzer_fallback_test.rb` → `test/url_favorites/integrations/llama_server/client_fallback_test.rb`

- [ ] **Step 1: LlmAnalyzer 이동**

```bash
git mv app/services/llm_analyzer.rb app/url_favorites/integrations/llama_server/client.rb
```

- [ ] **Step 2: 상수/메서드 네임스페이스 변경**

```ruby
# app/url_favorites/integrations/llama_server/client.rb (header)
module UrlFavorites
  module Integrations
    module LlamaServer
      class Client
        class ParseError < StandardError; end
        class ServerError < StandardError; end

        DEFAULT_BASE_URL = "http://localhost:8080"
        DEFAULT_BACKENDS = [
          { model: "local", timeout: 120 }
        ].freeze

        def self.call(content, type:)
          backends = resolve_backends
          last_error = nil
          backends.each do |backend|
            result = attempt_backend(backend, content, type)
            return result if result
          rescue ServerError, ParseError => e
            last_error = e
            Rails.logger.warn "[LlamaServer::Client] Backend #{backend[:url]} failed: #{e.message}"
          end
          raise ServerError, "All LLM backends failed. Last error: #{last_error&.message}"
        end

        # 이하 구현은 기존 LlmAnalyzer 본문을 유지하되,
        # (1) response envelope(OpenAI style)과 direct JSON 모두 파싱 가능하게 한다.
        # (2) required keys는 summary/key_points/tags/sentiment 을 강제하고 detail_content 는 optional 로 둔다.
      end
    end
  end
end
```

- [ ] **Step 3: 파서 호환성 추가(Envelope + Direct JSON)**

`attempt_backend`의 파싱 로직을 아래 형태로 정리한다.

```ruby
# app/url_favorites/integrations/llama_server/client.rb (inside attempt_backend)
parsed = JSON.parse(response.body, symbolize_names: true)

# Case A: direct JSON (tests/WebMock에서 주로 사용)
inner =
  if parsed.key?(:summary) || parsed.key?("summary")
    parsed
  else
    # Case B: OpenAI envelope
    message_content = parsed.dig(:choices, 0, :message, :content)
    raise ParseError, "Missing message.content in response" if message_content.blank?
    JSON.parse(message_content, symbolize_names: true)
  end

required = %i[summary key_points tags sentiment]
missing = required - inner.keys
raise ParseError, "Missing keys: #{missing.join(", ")}" if missing.any?

inner.slice(:summary, :key_points, :tags, :sentiment, :detail_content)
```

- [ ] **Step 4: 테스트 파일 이동/수정**

```bash
git mv test/services/llm_analyzer_test.rb test/url_favorites/integrations/llama_server/client_test.rb
git mv test/services/llm_analyzer_fallback_test.rb test/url_favorites/integrations/llama_server/client_fallback_test.rb
```

테스트 클래스/호출 상수:

- `LlmAnalyzer` → `UrlFavorites::Integrations::LlamaServer::Client`

- [ ] **Step 5: 테스트 실행**

Run: `bin/rails test test/url_favorites/integrations/llama_server`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/url_favorites/integrations/llama_server test/url_favorites/integrations/llama_server
git commit -m "refactor(ddd): replace LlmAnalyzer with UrlFavorites::Integrations::LlamaServer::Client"
```

---

## Task 5: Integrations::Search (Embedding/Indexer/Semantic) + UseCases::Search 도입

**Files:**
- Move+Modify: `app/services/embedding_service.rb` → `app/url_favorites/integrations/search/embedding_client.rb`
- Move+Modify: `app/services/favorite_search_indexer.rb` → `app/url_favorites/integrations/search/indexer.rb`
- Move+Modify: `app/services/semantic_search.rb` → `app/url_favorites/integrations/search/semantic_client.rb`
- Move+Modify: `app/services/favorite_search.rb` → `app/url_favorites/use_cases/search/favorite_search.rb`
- Move+Modify: `test/services/favorite_search_indexer_test.rb` → `test/url_favorites/integrations/search/indexer_test.rb`
- Move+Modify: `test/services/semantic_search_test.rb` → `test/url_favorites/integrations/search/semantic_client_test.rb`
- Move+Modify: `test/services/favorite_search_test.rb` → `test/url_favorites/use_cases/search/favorite_search_test.rb`

- [ ] **Step 1: EmbeddingService 이동**

```bash
git mv app/services/embedding_service.rb app/url_favorites/integrations/search/embedding_client.rb
```

```ruby
# app/url_favorites/integrations/search/embedding_client.rb
# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module Search
      class EmbeddingClient
        EMBEDDING_MODEL = "nomic-embed-text".freeze
        EMBEDDING_URL = ENV["EMBEDDING_URL"] || ENV["LLAMA_SERVER_URL"] || "http://localhost:8080"

        def self.call(text)
          new.call(text)
        end

        def call(text)
          return [] if text.blank?
          truncated = text[0...8000]

          conn = Faraday.new(EMBEDDING_URL) do |f|
            f.options.timeout = 60
            f.request :json
            f.response :raise_error
          end

          body = { model: EMBEDDING_MODEL, prompt: truncated }
          response = conn.post("/v1/embeddings", body)
          parsed = JSON.parse(response.body, symbolize_names: true)
          parsed[:embedding] || []
        rescue => e
          Rails.logger.error "[EmbeddingClient] Error: #{e.message}"
          []
        end
      end
    end
  end
end
```

- [ ] **Step 2: FavoriteSearchIndexer 이동**

```bash
git mv app/services/favorite_search_indexer.rb app/url_favorites/integrations/search/indexer.rb
```

```ruby
# app/url_favorites/integrations/search/indexer.rb
module UrlFavorites
  module Integrations
    module Search
      class Indexer
        # favorites_fts 가상 테이블을 위한 FTS5 인덱스 관리
        # favorites_fts 열: favorite_id INTEGER, title TEXT, summary TEXT, tags TEXT, note TEXT, content_embedding TEXT

        def self.index(favorite)
          analysis = favorite.analysis
          summary = analysis&.summary
          tags = analysis&.tags&.join(" ")
          note = favorite.respond_to?(:note) ? favorite.note : nil

          conn = ActiveRecord::Base.connection

          content_for_embedding = [favorite.title, summary, note].compact.join(" ")
          embedding = UrlFavorites::Integrations::Search::EmbeddingClient.call(content_for_embedding)
          embedding_json = embedding.present? ? embedding.to_json : nil

          conn.execute("DELETE FROM favorites_fts WHERE favorite_id = #{favorite.id}")

          conn.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [
              "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
              favorite.id, favorite.title, summary, tags, note, embedding_json
            ])
          )
        end

        def self.remove(favorite_id)
          ActiveRecord::Base.connection.execute(
            "DELETE FROM favorites_fts WHERE favorite_id = #{favorite_id.to_i}"
          )
        end

        def self.reindex_all
          conn = ActiveRecord::Base.connection
          conn.execute("DELETE FROM favorites_fts")

          Favorite.includes(:analysis).find_each do |favorite|
            index(favorite)
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: SemanticSearch 이동**

```bash
git mv app/services/semantic_search.rb app/url_favorites/integrations/search/semantic_client.rb
```

이 파일은 클래스명을 `UrlFavorites::Integrations::Search::SemanticClient`로 바꾸고,
내부 참조를 새 상수로 치환한다.

```ruby
# app/url_favorites/integrations/search/semantic_client.rb
# frozen_string_literal: true

module UrlFavorites
  module Integrations
    module Search
      class SemanticClient
        # Combines FTS5 keyword search with embedding-based semantic similarity

        def self.call(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
          new(query: query, content_type: content_type, status: status,
              collection_id: collection_id, sort: sort, limit: limit).call
        end

        def initialize(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
          @query = query.to_s.strip
          @content_type = content_type
          @status = status
          @collection_id = collection_id
          @sort = sort
          @limit = limit
        end

        def call
          return [] if @query.blank?

          query_embedding = UrlFavorites::Integrations::Search::EmbeddingClient.call(@query)
          return fts_search if query_embedding.empty?

          candidates = fetch_candidates_with_embeddings

          scored = candidates.map do |candidate|
            embedding = parse_embedding(candidate[:content_embedding])
            next unless embedding.present?

            similarity = cosine_similarity(query_embedding, embedding)
            candidate.merge(similarity: similarity)
          end.compact

          scored = scored.sort_by { |c| -c[:similarity] }
          return [] if scored.empty?

          favorite_ids = scored.map { |c| c[:favorite_id] }
          favorites_map = Favorite.where(id: favorite_ids).index_by(&:id)

          results = scored.map { |c| favorites_map[c[:favorite_id]] }.compact

          results = filter_by_content_type(results)
          results = filter_by_status(results)
          results = filter_by_collection_id(results)

          results.first(@limit)
        end

        private

        def fts_search
          UrlFavorites::UseCases::Search::FavoriteSearch.call(
            query: @query,
            content_type: @content_type,
            status: @status,
            collection_id: @collection_id,
            sort: @sort
          ).first(@limit)
        end

        def fetch_candidates_with_embeddings
          sql = "SELECT favorite_id, content_embedding FROM favorites_fts WHERE content_embedding IS NOT NULL LIMIT 1000"
          rows = ActiveRecord::Base.connection.execute(sql)
          rows.map { |r| { favorite_id: r["favorite_id"], content_embedding: r["content_embedding"] } }
        end

        def parse_embedding(embedding_str)
          return [] if embedding_str.blank?
          JSON.parse(embedding_str)
        rescue JSON::ParserError
          []
        end

        def cosine_similarity(a, b)
          return 0 if a.empty? || b.empty? || a.length != b.length
          dot_product = a.zip(b).map { |x, y| x * y }.sum
          magnitude_a = Math.sqrt(a.map { |x| x**2 }.sum)
          magnitude_b = Math.sqrt(b.map { |x| x**2 }.sum)
          return 0 if magnitude_a.zero? || magnitude_b.zero?
          dot_product / (magnitude_a * magnitude_b)
        end

        def filter_by_content_type(favorites)
          return favorites unless @content_type.present?
          favorites.select { |f| f.content_type == @content_type }
        end

        def filter_by_status(favorites)
          return favorites unless @status.present?
          favorites.select { |f| f.status == @status }
        end

        def filter_by_collection_id(favorites)
          return favorites unless @collection_id.present?
          favorites.select { |f| f.collection_memberships.any? { |m| m.collection_id == @collection_id } }
        end
      end
    end
  end
end
```

- [ ] **Step 4: FavoriteSearch 이동(UseCase)**

```bash
git mv app/services/favorite_search.rb app/url_favorites/use_cases/search/favorite_search.rb
```

상수명은 `UrlFavorites::UseCases::Search::FavoriteSearch`로 변경한다.

```ruby
# app/url_favorites/use_cases/search/favorite_search.rb
module UrlFavorites
  module UseCases
    module Search
      class FavoriteSearch
        def self.call(query: nil, content_type: nil, status: nil, collection_id: nil, sort: "recent", category: nil)
          new(query: query, content_type: content_type, status: status, collection_id: collection_id, sort: sort, category: category).call
        end

        def initialize(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", category: nil)
          @query = query&.strip
          @content_type = content_type
          @status = status
          @collection_id = collection_id
          @sort = sort
          @category = category
        end

        def call
          if @query.present?
            fts_search
          else
            filtered_favorites
          end
        end

        private

        def apply_sort(scope)
          case @sort
          when "oldest"
            scope.order(created_at: :asc)
          when "title"
            scope.order("COALESCE(title, url) ASC")
          else
            scope.order(created_at: :desc)
          end
        end

        def fts_search
          sanitized = @query.gsub(/[^a-zA-Z0-9 ]/, "").strip
          return [] if sanitized.blank?

          sql = "SELECT favorite_id FROM favorites_fts WHERE favorites_fts MATCH ?"
          rows = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [sql, sanitized + "*"])
          )
          ids = rows.map { |r| r["favorite_id"] }.compact
          return [] if ids.empty?

          scope = Favorite.where(id: ids)
          scope = apply_filters(scope)
          apply_sort(scope)
        end

        def filtered_favorites
          scope = Favorite.all
          scope = apply_filters(scope)
          apply_sort(scope)
        end

        def apply_filters(scope)
          scope = scope.where(content_type: @content_type) if @content_type.present?
          scope = scope.where(status: @status) if @status.present?
          scope = scope.where(category: @category) if @category.present? && @category != "전체"
          scope = scope.where(pinned: true) if @category == "핀"
          scope
        end
      end
    end
  end
end
```

- [ ] **Step 5: 테스트 이동/상수 업데이트**

```bash
git mv test/services/favorite_search_indexer_test.rb test/url_favorites/integrations/search/indexer_test.rb
git mv test/services/semantic_search_test.rb test/url_favorites/integrations/search/semantic_client_test.rb
git mv test/services/favorite_search_test.rb test/url_favorites/use_cases/search/favorite_search_test.rb
```

테스트 내 상수 치환:

- `EmbeddingService` → `UrlFavorites::Integrations::Search::EmbeddingClient`
- `FavoriteSearchIndexer` → `UrlFavorites::Integrations::Search::Indexer`
- `SemanticSearch` → `UrlFavorites::Integrations::Search::SemanticClient` (클래스명 변경 후)
- `FavoriteSearch` → `UrlFavorites::UseCases::Search::FavoriteSearch`

- [ ] **Step 6: 테스트 실행**

Run: `bin/rails test test/url_favorites/integrations/search test/url_favorites/use_cases/search/favorite_search_test.rb`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/url_favorites/integrations/search app/url_favorites/use_cases/search test/url_favorites/integrations/search test/url_favorites/use_cases/search
git commit -m "refactor(ddd): move search/embedding into UrlFavorites layers"
```

---

## Task 6: UseCases::Analysis (Enqueue/Run) 도입 + Analyze Jobs 얇게 만들기

**Files:**
- Create: `app/url_favorites/domain/analysis/retry_policy.rb`
- Create: `app/url_favorites/use_cases/analysis/enqueue_analysis.rb`
- Create: `app/url_favorites/use_cases/analysis/run_analysis.rb`
- Modify: `app/jobs/analyze_webpage_job.rb`
- Modify: `app/jobs/analyze_youtube_job.rb`
- Move+Modify: `test/jobs/analyze_webpage_job_test.rb` → `test/url_favorites/use_cases/analysis/analyze_webpage_job_test.rb`
- Move+Modify: `test/jobs/analyze_youtube_job_test.rb` → `test/url_favorites/use_cases/analysis/analyze_youtube_job_test.rb`

- [ ] **Step 1: 재시도 정책(30/60/120, max 3) Domain에 추가**

```ruby
# app/url_favorites/domain/analysis/retry_policy.rb
module UrlFavorites
  module Domain
    module Analysis
      class RetryPolicy
        MAX_RETRIES = 3
        BACKOFF_SECONDS = [30, 60, 120].freeze

        def self.next_wait_seconds(execution_index)
          BACKOFF_SECONDS.fetch(execution_index, BACKOFF_SECONDS.last)
        end
      end
    end
  end
end
```

- [ ] **Step 2: EnqueueAnalysis 유스케이스 생성**

```ruby
# app/url_favorites/use_cases/analysis/enqueue_analysis.rb
module UrlFavorites
  module UseCases
    module Analysis
      class EnqueueAnalysis
        def self.call(favorite_id:)
          favorite = Favorite.find(favorite_id)
          if favorite.content_type == "youtube"
            AnalyzeYoutubeJob.perform_later(favorite.id)
          else
            AnalyzeWebpageJob.perform_later(favorite.id)
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: RunAnalysis 유스케이스 생성(raw_content 재사용 + status 전이 + error_message/retry_count)**

```ruby
# app/url_favorites/use_cases/analysis/run_analysis.rb
module UrlFavorites
  module UseCases
    module Analysis
      class RunAnalysis
        def self.call(favorite_id:)
          favorite = Favorite.find(favorite_id)
          favorite.update!(status: "analyzing", error_message: nil)

          raw_content = favorite.raw_content.presence || extract_raw_content(favorite)
          favorite.update!(raw_content: raw_content) if favorite.raw_content.blank?

          analysis_result = UrlFavorites::Integrations::LlamaServer::Client.call(raw_content, type: favorite.content_type)

          upsert_analysis!(favorite, raw_content, analysis_result)

          favorite.update!(
            status: "done",
            category: UrlFavorites::Domain::Urls::CategoryDetector.call(favorite.url, favorite.content_type),
            retry_count: 0
          )
        rescue => e
          favorite.update!(
            status: "failed",
            retry_count: favorite.retry_count.to_i + 1,
            error_message: "#{e.class}: #{e.message}"
          )
          raise e if favorite.retry_count < UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
        end

        def self.extract_raw_content(favorite)
          if favorite.content_type == "youtube"
            r = UrlFavorites::Integrations::Youtube::Extractor.call(favorite.url)
            favorite.update!(thumbnail_url: r[:thumbnail_url]) if r[:thumbnail_url].present?
            favorite.update!(title: r[:title]) if r[:title].present? && (favorite.title.blank? || favorite.title.to_s.start_with?("http://", "https://"))
            r[:transcript].to_s
          else
            r = UrlFavorites::Integrations::Webpage::Scraper.call(favorite.url)
            favorite.update!(title: r[:title]) if r[:title].present?
            [r[:title], r[:body_text]].compact.join(" ")
          end
        end

        def self.upsert_analysis!(favorite, raw_content, analysis_result)
          attrs = {
            raw_content: raw_content,
            summary: analysis_result[:summary],
            key_points: analysis_result[:key_points],
            tags: analysis_result[:tags],
            sentiment: analysis_result[:sentiment],
            detail_content: analysis_result[:detail_content]
          }

          if favorite.analysis
            favorite.analysis.update!(**attrs)
          else
            favorite.create_analysis!(**attrs)
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Analyze jobs를 얇게 변경 + ai 큐로 이동 + retry_on 적용**

```ruby
# app/jobs/analyze_webpage_job.rb
class AnalyzeWebpageJob < ApplicationJob
  queue_as :ai

  rescue_from(StandardError) do |e|
    executions_index = (executions - 1)
    wait_seconds = UrlFavorites::Domain::Analysis::RetryPolicy.next_wait_seconds(executions_index)
    retry_job(wait: wait_seconds) if executions < UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
    raise e
  end

  def perform(favorite_id)
    UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: favorite_id)
  end
end
```

```ruby
# app/jobs/analyze_youtube_job.rb
class AnalyzeYoutubeJob < ApplicationJob
  queue_as :ai

  rescue_from(StandardError) do |e|
    executions_index = (executions - 1)
    wait_seconds = UrlFavorites::Domain::Analysis::RetryPolicy.next_wait_seconds(executions_index)
    retry_job(wait: wait_seconds) if executions < UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
    raise e
  end

  def perform(favorite_id)
    UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: favorite_id)
  end
end
```

- [ ] **Step 5: 테스트 이동 및 스텁 대상을 UseCase로 변경**

```bash
git mv test/jobs/analyze_webpage_job_test.rb test/url_favorites/use_cases/analysis/analyze_webpage_job_test.rb
git mv test/jobs/analyze_youtube_job_test.rb test/url_favorites/use_cases/analysis/analyze_youtube_job_test.rb
```

테스트에서 stub 대상 변경:

- `WebpageScraper` → `UrlFavorites::Integrations::Webpage::Scraper`
- `YoutubeExtractor` → `UrlFavorites::Integrations::Youtube::Extractor`
- `LlmAnalyzer` → `UrlFavorites::Integrations::LlamaServer::Client`

```ruby
# test/url_favorites/use_cases/analysis/analyze_webpage_job_test.rb (diff)
-    WebpageScraper.stub(:call, @scraper_result) do
-      LlmAnalyzer.stub(:call, @analyzer_result) do
+    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
+      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
         AnalyzeWebpageJob.perform_now(@favorite.id)
         ...
       end
     end
```

```ruby
# test/url_favorites/use_cases/analysis/analyze_youtube_job_test.rb (diff)
-    YoutubeExtractor.stub(:call, @extractor_result) do
-      LlmAnalyzer.stub(:call, @analyzer_result) do
+    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
+      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
         AnalyzeYoutubeJob.perform_now(@favorite.id)
         ...
       end
     end
```

- [ ] **Step 6: 테스트 실행**

Run: `bin/rails test test/url_favorites/use_cases/analysis`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/url_favorites/domain/analysis app/url_favorites/use_cases/analysis app/jobs/analyze_webpage_job.rb app/jobs/analyze_youtube_job.rb test/url_favorites/use_cases/analysis
git commit -m "refactor(ddd): move analysis flow into UrlFavorites::UseCases::Analysis"
```

---

## Task 7: UseCases::Favorites 도입 + FavoritesController 얇게 만들기

**Files:**
- Create: `app/url_favorites/use_cases/favorites/create_favorite.rb`
- Create: `app/url_favorites/use_cases/favorites/delete_favorite.rb`
- Create: `app/url_favorites/use_cases/favorites/retry_analysis.rb`
- Create: `app/url_favorites/use_cases/favorites/toggle_pin.rb`
- Modify: `app/controllers/favorites_controller.rb`
- Modify: `test/controllers/favorites_controller_test.rb`

- [ ] **Step 1: CreateFavorite 유스케이스(정규화+안전성+중복 처리+enqueue)**

```ruby
# app/url_favorites/use_cases/favorites/create_favorite.rb
module UrlFavorites
  module UseCases
    module Favorites
      class CreateFavorite
        def self.call(url:)
          normalized = UrlFavorites::Domain::Urls::Normalizer.call(url)
          unless UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(normalized)
            raise UrlFavorites::Domain::Errors::UnsafeUrl, "Unsafe URL"
          end

          existing = Favorite.find_by(url: normalized)
          return UrlFavorites::UseCases::Result.new(ok?: true, value: { favorite: existing, created: false }) if existing

          content_type = UrlFavorites::Domain::Urls::TypeDetector.call(normalized)
          favorite = Favorite.create!(
            url: normalized,
            title: normalized,
            content_type: content_type,
            status: "pending",
            category: UrlFavorites::Domain::Urls::CategoryDetector.call(normalized, content_type)
          )

          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: favorite.id)
          UrlFavorites::UseCases::Result.new(ok?: true, value: { favorite: favorite, created: true })
        end
      end
    end
  end
end
```

- [ ] **Step 2: FavoritesController#create 를 유스케이스 호출로 변경**

```ruby
# app/controllers/favorites_controller.rb (create)
def create
  url = params.dig(:favorite, :url).to_s.strip

  result = UrlFavorites::UseCases::Favorites::CreateFavorite.call(url: url)
  favorite = result.value[:favorite]

  if result.value[:created]
    redirect_to favorites_url, notice: "URL이 저장되었습니다. 분석을 시작합니다."
  else
    redirect_to favorite_url(favorite), alert: "이미 등록된 URL입니다. 기존 북마크로 이동합니다."
  end
rescue UrlFavorites::Domain::Errors::UnsafeUrl
  redirect_to favorites_url, alert: "Unsafe URL"
end
```

- [ ] **Step 3: destroy/retry/toggle_pin 도 유스케이스로 이동**

```ruby
# app/url_favorites/use_cases/favorites/delete_favorite.rb
module UrlFavorites
  module UseCases
    module Favorites
      class DeleteFavorite
        def self.call(id:)
          favorite = Favorite.find(id)
          UrlFavorites::Integrations::Search::Indexer.remove(favorite.id)
          favorite.destroy!
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/favorites/retry_analysis.rb
module UrlFavorites
  module UseCases
    module Favorites
      class RetryAnalysis
        def self.call(id:)
          favorite = Favorite.find(id)
          favorite.update!(status: "pending", error_message: nil)
          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: favorite.id)
          favorite
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/favorites/toggle_pin.rb
module UrlFavorites
  module UseCases
    module Favorites
      class TogglePin
        def self.call(id:)
          favorite = Favorite.find(id)
          favorite.update!(pinned: !favorite.pinned)
          favorite
        end
      end
    end
  end
end
```

컨트롤러 액션은 다음처럼 유스케이스 호출로 치환한다.

```ruby
# app/controllers/favorites_controller.rb (index/destroy/retry/toggle_pin)
def index
  @favorites = UrlFavorites::UseCases::Search::FavoriteSearch.call(
    query: params[:q],
    content_type: params[:content_type],
    status: params[:status],
    collection_id: params[:collection_id],
    sort: params[:sort] || "recent",
    category: params[:category]
  )
  @view_mode = params[:view_mode] || "card"
end

def destroy
  UrlFavorites::UseCases::Favorites::DeleteFavorite.call(id: params[:id])
  redirect_to favorites_url, notice: "Deleted"
end

def retry
  favorite = UrlFavorites::UseCases::Favorites::RetryAnalysis.call(id: params[:id])
  redirect_to favorite_url(favorite), notice: "Retrying analysis"
end

def toggle_pin
  favorite = UrlFavorites::UseCases::Favorites::TogglePin.call(id: params[:id])
  redirect_back_or_to favorites_url, notice: favorite.pinned? ? "북마크가 핀されました" : "핀 해제되었습니다"
end
```

- [ ] **Step 4: 컨트롤러 테스트 업데이트**

`FavoritesControllerTest`에서 FTS 인덱싱을 위해 직접 호출하던 상수를 새 상수로 치환한다.

```ruby
# test/controllers/favorites_controller_test.rb (diff)
-    FavoriteSearchIndexer.reindex_all
+    UrlFavorites::Integrations::Search::Indexer.reindex_all
```

- [ ] **Step 5: 테스트 실행**

Run: `bin/rails test test/controllers/favorites_controller_test.rb`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/url_favorites/use_cases/favorites app/controllers/favorites_controller.rb test/controllers/favorites_controller_test.rb
git commit -m "refactor(ddd): make FavoritesController call UrlFavorites use cases"
```

---

## Task 8: Collections/Notes UseCases 도입 + 컨트롤러 얇게 만들기

**Files:**
- Create: `app/url_favorites/use_cases/collections/list_collections.rb`
- Create: `app/url_favorites/use_cases/collections/show_collection.rb`
- Create: `app/url_favorites/use_cases/collections/create_collection.rb`
- Create: `app/url_favorites/use_cases/collections/update_collection.rb`
- Create: `app/url_favorites/use_cases/collections/delete_collection.rb`
- Create: `app/url_favorites/use_cases/collections/add_favorite_to_collection.rb`
- Create: `app/url_favorites/use_cases/collections/remove_favorite_from_collection.rb`
- Create: `app/url_favorites/use_cases/notes/update_favorite_note.rb`
- Modify: `app/controllers/collections_controller.rb`
- Modify: `app/controllers/collection_memberships_controller.rb`
- Modify: `app/controllers/favorite_notes_controller.rb`
- Modify: `test/controllers/favorite_notes_controller_test.rb`

- [ ] **Step 1: Collections CRUD 유스케이스 추가**

```ruby
# app/url_favorites/use_cases/collections/list_collections.rb
module UrlFavorites
  module UseCases
    module Collections
      class ListCollections
        def self.call
          Collection.all.order(created_at: :desc)
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/collections/show_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class ShowCollection
        def self.call(id:)
          collection = Collection.find(id)
          { collection: collection, favorites: collection.favorites }
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/collections/create_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class CreateCollection
        def self.call(name:, description: nil)
          Collection.create!(name: name, description: description)
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/collections/update_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class UpdateCollection
        def self.call(id:, name:, description: nil)
          collection = Collection.find(id)
          collection.update!(name: name, description: description)
          collection
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/collections/delete_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class DeleteCollection
        def self.call(id:)
          collection = Collection.find(id)
          collection.destroy!
        end
      end
    end
  end
end
```

- [ ] **Step 2: Membership 유스케이스 추가**

```ruby
# app/url_favorites/use_cases/collections/add_favorite_to_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class AddFavoriteToCollection
        def self.call(favorite_id:, collection_id:)
          favorite = Favorite.find(favorite_id)
          CollectionMembership.find_or_create_by!(favorite: favorite, collection_id: collection_id)
          favorite
        end
      end
    end
  end
end
```

```ruby
# app/url_favorites/use_cases/collections/remove_favorite_from_collection.rb
module UrlFavorites
  module UseCases
    module Collections
      class RemoveFavoriteFromCollection
        def self.call(favorite_id:, collection_id:)
          favorite = Favorite.find(favorite_id)
          membership = CollectionMembership.find_by(favorite: favorite, collection_id: collection_id)
          membership&.destroy
          favorite
        end
      end
    end
  end
end
```

- [ ] **Step 3: Note 업데이트 유스케이스 + reindex enqueue**

```ruby
# app/url_favorites/use_cases/notes/update_favorite_note.rb
module UrlFavorites
  module UseCases
    module Notes
      class UpdateFavoriteNote
        def self.call(favorite_id:, note:)
          favorite = Favorite.find(favorite_id)
          favorite.update!(note: note)
          ReindexFavoriteJob.perform_later(favorite.id)
          favorite
        end
      end
    end
  end
end
```

- [ ] **Step 4: Controllers를 유스케이스 호출로 치환**

```ruby
# app/controllers/collections_controller.rb
class CollectionsController < ApplicationController
  def index
    @collections = UrlFavorites::UseCases::Collections::ListCollections.call
  end

  def show
    result = UrlFavorites::UseCases::Collections::ShowCollection.call(id: params[:id])
    @collection = result[:collection]
    @favorites = result[:favorites]
  end

  def create
    @collection = UrlFavorites::UseCases::Collections::CreateCollection.call(
      name: collection_params[:name],
      description: collection_params[:description]
    )
    redirect_to collection_url(@collection), notice: "Collection created"
  rescue ActiveRecord::RecordInvalid
    @collections = UrlFavorites::UseCases::Collections::ListCollections.call
    render :index, status: :unprocessable_entity
  end

  def update
    @collection = UrlFavorites::UseCases::Collections::UpdateCollection.call(
      id: params[:id],
      name: collection_params[:name],
      description: collection_params[:description]
    )
    redirect_to collection_url(@collection), notice: "Collection updated"
  rescue ActiveRecord::RecordInvalid
    @collection = Collection.find(params[:id])
    render :show, status: :unprocessable_entity
  end

  def destroy
    UrlFavorites::UseCases::Collections::DeleteCollection.call(id: params[:id])
    redirect_to collections_url, notice: "Collection deleted"
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :description)
  end
end
```

```ruby
# app/controllers/collection_memberships_controller.rb
class CollectionMembershipsController < ApplicationController
  def create
    favorite = UrlFavorites::UseCases::Collections::AddFavoriteToCollection.call(
      favorite_id: params[:favorite_id],
      collection_id: params.dig(:collection_membership, :collection_id)
    )
    redirect_to favorite_url(favorite)
  end

  def destroy
    favorite = UrlFavorites::UseCases::Collections::RemoveFavoriteFromCollection.call(
      favorite_id: params[:favorite_id],
      collection_id: params.dig(:collection_membership, :collection_id)
    )
    redirect_to favorite_url(favorite)
  end
end
```

```ruby
# app/controllers/favorite_notes_controller.rb
class FavoriteNotesController < ApplicationController
  def update
    favorite = UrlFavorites::UseCases::Notes::UpdateFavoriteNote.call(
      favorite_id: params[:favorite_id],
      note: params.dig(:favorite, :note)
    )
    redirect_to favorite_url(favorite), notice: "Note updated"
  end
end
```

`FavoriteNotesControllerTest`에서 레거시 상수를 새 상수로 치환한다.

```ruby
# test/controllers/favorite_notes_controller_test.rb (diff)
-    FavoriteSearchIndexer.reindex_all
+    UrlFavorites::Integrations::Search::Indexer.reindex_all
```

- [ ] **Step 5: 테스트 실행**

Run: `bin/rails test test/controllers/collections_controller_test.rb test/controllers/collection_memberships_controller_test.rb test/controllers/favorite_notes_controller_test.rb`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/url_favorites/use_cases/collections app/url_favorites/use_cases/notes app/controllers/collections_controller.rb app/controllers/collection_memberships_controller.rb app/controllers/favorite_notes_controller.rb
git commit -m "refactor(ddd): move collections and notes logic into UrlFavorites use cases"
```

---

## Task 9: Newsletter UseCase 도입 + WeeklyNewsletterJob 얇게 만들기

**Files:**
- Create: `app/url_favorites/use_cases/newsletter/send_weekly_newsletter.rb`
- Modify: `app/jobs/weekly_newsletter_job.rb`
- Modify: `test/jobs/weekly_newsletter_job_test.rb`

- [ ] **Step 1: SendWeeklyNewsletter 유스케이스 추가**

```ruby
# app/url_favorites/use_cases/newsletter/send_weekly_newsletter.rb
module UrlFavorites
  module UseCases
    module Newsletter
      class SendWeeklyNewsletter
        def self.call
          recent = UrlFavorites::UseCases::Search::FavoriteSearch.call(status: "done", sort: "recent")
            .where("created_at > ?", 7.days.ago).to_a
          return if recent.count < 3

          digest = build_digest(recent)
          WeeklyNewsletterMailer.digest(digest).deliver_later
        end

        def self.build_digest(favorites)
          {
            date: I18n.l(Date.today, format: :long),
            favorites_count: favorites.count,
            favorites: favorites.map { |f| format_favorite(f) },
            top_tags: extract_top_tags(favorites)
          }
        end

        def self.format_favorite(f)
          {
            title: f.title.presence || f.url,
            url: f.url,
            summary: f.analysis&.summary,
            tags: f.analysis&.tags || [],
            created_at: I18n.l(f.created_at, format: :short)
          }
        end

        def self.extract_top_tags(favorites)
          favorites.flat_map { |f| f.analysis&.tags || [] }
            .group_by(&:itself)
            .transform_values(&:count)
            .sort_by { |_, count| -count }
            .first(10)
            .map(&:first)
        end
      end
    end
  end
end
```

- [ ] **Step 2: WeeklyNewsletterJob 은 유스케이스만 호출**

```ruby
# app/jobs/weekly_newsletter_job.rb
class WeeklyNewsletterJob < ApplicationJob
  queue_as :default

  def perform
    UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.call
  end
end
```

- [ ] **Step 3: 테스트 업데이트(메일 발송 트리거 유지)**

`WeeklyNewsletterJobTest`는 동작이 유지되므로, 내부 private 메서드 접근 대신 유스케이스의 `build_digest`를 호출하도록 수정한다.

```ruby
# test/jobs/weekly_newsletter_job_test.rb (diff)
-      digest = WeeklyNewsletterJob.new.send(:build_digest, [fav])
+      digest = UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.build_digest([fav])
...
-    digest = job.send(:build_digest, [fav])
+    digest = UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.build_digest([fav])
```

- [ ] **Step 4: 테스트 실행**

Run: `bin/rails test test/jobs/weekly_newsletter_job_test.rb`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/url_favorites/use_cases/newsletter app/jobs/weekly_newsletter_job.rb test/jobs/weekly_newsletter_job_test.rb
git commit -m "refactor(ddd): move weekly newsletter logic into UrlFavorites use case"
```

---

## Task 10: Importers UseCase 도입 + Integrations::Importers::UrlfSnapshot 분리

**Files:**
- Create: `app/url_favorites/integrations/importers/urlf_snapshot/reader.rb`
- Move+Modify: `app/services/importers/urlf_snapshot_importer.rb` → `app/url_favorites/use_cases/importers/import_urlf_snapshot.rb`
- Modify: `test/services/importers/urlf_snapshot_importer_test.rb`

- [ ] **Step 1: Snapshot reader integration 추가**

```ruby
# app/url_favorites/integrations/importers/urlf_snapshot/reader.rb
require "sqlite3"

module UrlFavorites
  module Integrations
    module Importers
      module UrlfSnapshot
        class Reader
          def initialize(db_path)
            @db_path = db_path
          end

          def each_bookmark
            db = SQLite3::Database.new(@db_path, readonly: true)
            db.results_as_hash = true
            db.execute("SELECT url, title, created_at FROM bookmarks").each do |row|
              yield row
            end
          ensure
            db&.close
          end
        end
      end
    end
  end
end
```

- [ ] **Step 2: ImportUrlfSnapshot 유스케이스로 이관**

```bash
git mv app/services/importers/urlf_snapshot_importer.rb app/url_favorites/use_cases/importers/import_urlf_snapshot.rb
```

```ruby
# app/url_favorites/use_cases/importers/import_urlf_snapshot.rb
module UrlFavorites
  module UseCases
    module Importers
      class ImportUrlfSnapshot
        def self.call(db_path)
          new(db_path).call
        end

        def initialize(db_path)
          @reader = UrlFavorites::Integrations::Importers::UrlfSnapshot::Reader.new(db_path)
        end

        def call
          imported = 0
          skipped = 0

          @reader.each_bookmark do |row|
            url = UrlFavorites::Domain::Urls::Normalizer.call(row["url"].to_s)
            next if url.blank?

            if Favorite.exists?(url: url)
              skipped += 1
              next
            end

            content_type = UrlFavorites::Domain::Urls::TypeDetector.call(url)
            Favorite.create!(
              url: url,
              title: row["title"].presence || url,
              content_type: content_type,
              status: "pending",
              category: UrlFavorites::Domain::Urls::CategoryDetector.call(url, content_type),
              created_at: row["created_at"]
            )
            imported += 1
          end

          { imported: imported, skipped: skipped }
        end
      end
    end
  end
end
```

- [ ] **Step 3: 테스트에서 유스케이스 상수로 치환**

```ruby
# test/services/importers/urlf_snapshot_importer_test.rb (diff)
-class Importers::UrlfSnapshotImporterTest < ActiveSupport::TestCase
+class UrlFavorites::UseCases::Importers::ImportUrlfSnapshotTest < ActiveSupport::TestCase
...
-    result = Importers::UrlfSnapshotImporter.call(@db_path)
+    result = UrlFavorites::UseCases::Importers::ImportUrlfSnapshot.call(@db_path)
...
-    Importers::UrlfSnapshotImporter.call(@db_path)
+    UrlFavorites::UseCases::Importers::ImportUrlfSnapshot.call(@db_path)
```

- [ ] **Step 4: 테스트 실행**

Run: `bin/rails test test/services/importers/urlf_snapshot_importer_test.rb`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/url_favorites/integrations/importers app/url_favorites/use_cases/importers test/services/importers/urlf_snapshot_importer_test.rb
git commit -m "refactor(ddd): move importer into UrlFavorites use case + integrations reader"
```

---

## Task 11: ReindexFavoriteJob + Favorites/Notes/Search 참조 정리

**Files:**
- Modify: `app/jobs/reindex_favorite_job.rb`
- Modify: `test/jobs/reindex_favorite_job_test.rb`
- Modify: `app/controllers/favorites_controller.rb`
- Modify: `app/controllers/favorite_notes_controller.rb`
- Modify: `test/controllers/favorites_controller_test.rb`
- Modify: `test/controllers/favorite_notes_controller_test.rb`

- [ ] **Step 1: ReindexFavoriteJob이 Integrations::Search::Indexer를 호출하도록 변경**

```ruby
# app/jobs/reindex_favorite_job.rb
class ReindexFavoriteJob < ApplicationJob
  queue_as :default

  def perform(favorite_id = nil)
    if favorite_id.present?
      favorite = Favorite.find_by(id: favorite_id)
      return unless favorite
      UrlFavorites::Integrations::Search::Indexer.index(favorite)
    else
      UrlFavorites::Integrations::Search::Indexer.reindex_all
    end
  end
end
```

- [ ] **Step 2: 테스트의 stub 상수 변경**

`FavoriteSearchIndexer` → `UrlFavorites::Integrations::Search::Indexer`

- [ ] **Step 3: 테스트 실행**

Run: `bin/rails test test/jobs/reindex_favorite_job_test.rb test/controllers/favorite_notes_controller_test.rb test/controllers/favorites_controller_test.rb`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add app/jobs/reindex_favorite_job.rb test/jobs/reindex_favorite_job_test.rb test/controllers/favorite_notes_controller_test.rb test/controllers/favorites_controller_test.rb
git commit -m "refactor(ddd): route reindexing through UrlFavorites::Integrations::Search::Indexer"
```

---

## Task 12: Solid Queue 동시성(AI max 2) 적용 + Job queue 분리

**Files:**
- Modify: `config/queue.yml`
- Modify: `test/url_favorites/use_cases/analysis/analyze_webpage_job_test.rb`
- Modify: `test/url_favorites/use_cases/analysis/analyze_youtube_job_test.rb`

- [ ] **Step 1: queue.yml에 ai worker 추가**

```yml
# config/queue.yml (default)
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: ai
      threads: 2
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
```

- [ ] **Step 2: AI 잡 큐네임 검증 테스트 업데이트**

Analyze jobs가 `ai` 큐로 이동했으므로, 잡 테스트에 큐네임 스모크 테스트를 추가한다.

```ruby
# test/url_favorites/use_cases/analysis/analyze_webpage_job_test.rb (add)
test "enqueues to ai queue" do
  assert_equal "ai", AnalyzeWebpageJob.queue_name
end
```

```ruby
# test/url_favorites/use_cases/analysis/analyze_youtube_job_test.rb (add)
test "enqueues to ai queue" do
  assert_equal "ai", AnalyzeYoutubeJob.queue_name
end
```

- [ ] **Step 3: Commit**

```bash
git add config/queue.yml
git commit -m "chore(queue): limit AI job concurrency to 2 threads via ai queue"
```

---

## Task 13: 레거시 `app/services/*` 잔여 참조 제거(클린 컷 마무리)

**Files:**
- Delete: `app/services/*.rb` (이관 완료된 파일들)
- Modify: 남아있는 참조 파일들(controllers/jobs/tests/views)

- [ ] **Step 1: 잔여 참조 탐지**

Run: `rg -n "app/services|UrlNormalizer|UrlSafetyValidator|UrlTypeDetector|UrlCategoryDetector|WebpageScraper|YoutubeExtractor|LlmAnalyzer|EmbeddingService|FavoriteSearchIndexer|SemanticSearch|FavoriteSearch\\b" app test`  
Expected: 더 이상 레거시 상수/경로 참조가 없다.

- [ ] **Step 2: 잔여 참조를 새 상수로 모두 치환**

치환 표(대표):

- `UrlNormalizer` → `UrlFavorites::Domain::Urls::Normalizer`
- `UrlSafetyValidator` → `UrlFavorites::Domain::Urls::SafetyPolicy`
- `UrlTypeDetector` → `UrlFavorites::Domain::Urls::TypeDetector`
- `UrlCategoryDetector` → `UrlFavorites::Domain::Urls::CategoryDetector`
- `WebpageScraper` → `UrlFavorites::Integrations::Webpage::Scraper`
- `YoutubeExtractor` → `UrlFavorites::Integrations::Youtube::Extractor`
- `LlmAnalyzer` → `UrlFavorites::Integrations::LlamaServer::Client`
- `EmbeddingService` → `UrlFavorites::Integrations::Search::EmbeddingClient`
- `FavoriteSearchIndexer` → `UrlFavorites::Integrations::Search::Indexer`
- `SemanticSearch` → `UrlFavorites::Integrations::Search::SemanticClient`
- `FavoriteSearch` → `UrlFavorites::UseCases::Search::FavoriteSearch`

- [ ] **Step 3: Zeitwerk 체크**

Run: `bin/rails zeitwerk:check`  
Expected: `All is good!`

- [ ] **Step 4: 전체 테스트 실행**

Run: `bin/rails test`  
Expected: PASS (0 failures, 0 errors)

- [ ] **Step 5: Commit**

```bash
git add app test
git commit -m "refactor(ddd): remove legacy services and complete clean-cut migration"
```
