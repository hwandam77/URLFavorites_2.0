module UrlFavorites
  module Domain
    module Urls
      class CategoryDetector
        # 플랫 12개 카테고리 체계
        CATEGORIES = %w[
          AI에이전트 AI코딩 AI모델 프론트엔드 백엔드 DevOps
          데이터베이스 보안 디자인 뉴스 튜토리얼 기타
        ].freeze

        CATEGORY_PATTERNS = {
          "AI에이전트" => [
            /langchain\.ai|llamaindex\.ai|crewai\.com|autogen\.ai/i,
            /mcp\.run|mcp\.iit|modelcontextprotocol\.github/i,
            /multiagent|agent.?framework|agent.?loop|agent.?orchestrat/i,
            /crewai|autogen|autonomous.?agent|reasoning.?engine/i,
            /pinecone|weaviate|chroma.?db|vector.?db|rag.?retrieval/i,
          ],
          "AI코딩" => [
            /cursor\.sh|windsurf\.ai|claude\.dev|v0\.dev/i,
            /bolt\.new|replit\.com|lovable\.dev|devin\.ai/i,
            /github\.copilot|cursor|windsurf|claude.?code/i,
            /codex|copilot|coding.?agent|vibe.?coding/i,
            /code.?generation|ai.?code.?review|automated.?refactor/i,
          ],
          "AI모델" => [
            /huggingface\.co|ollama\.ai|vllm\.github/i,
            /anthropic\.com|openai\.com|chatgpt\.com|cohere\.ai/i,
            /mistral\.ai|qwen\.tongyi|deepseek\.ai|groq\.com/i,
            /lepton\.ai|replicate\.com/i,
            /transformers|llama|gemini|claude|gpt|ollama/i,
            /model.?hub|pretrained|fine.?tuning|rlhf|llm.?benchmark/i,
            /mistral|qwen|deepseek|command[_-]?r|yi.?34b/i,
          ],
          "프론트엔드" => [
            /react|vue\.js|svelte|next\.js|nuxt|remix/i,
            /tailwind|bootstrap|material.?ui|chakra.?ui/i,
            /figma\.com|dribbble\.com|codepen\.io/i,
            /css|html|javascript|typescript|webpack|vite/i,
            /ui.?component|design.?system|front.?end/i,
          ],
          "백엔드" => [
            /rails|django|flask|spring|express|fastapi/i,
            /graphql|rest.?api|grpc|microservice/i,
            /redis|memcached|rabbitmq|kafka/i,
            /authentication|oauth|jwt|api.?gateway/i,
          ],
          "DevOps" => [
            /docker\.com|kubernetes\.io|terraform\.io|ansible\.com/i,
            /github\.com\/.*actions|circleci|jenkins|gitlab-ci/i,
            /docker|kubernetes|k8s|helm|docker.?compose/i,
            /ci\/cd|pipeline|deploy|monitoring|observabilit/i,
            /prometheus|grafana|datadog|sentry/i,
          ],
          "데이터베이스" => [
            /postgresql|mysql|mariadb|sqlite/i,
            /mongodb|couchdb|neo4j|arangodb/i,
            /elastic.?search|opensearch|meilisearch/i,
            /database|sql|nosql|data.?pipeline|etl/i,
          ],
          "보안" => [
            /owasp|CVE|vulnerabilit|exploit|pentest/i,
            /encryption|cipher|tls|ssl|certificate/i,
            /firewall|ids|ips|siem|security.?audit/i,
            /auth.?security|2fa|mfa|zero.?trust/i,
          ],
          "디자인" => [
            /figma\.com|sketch\.com|canva\.com|dribbble\.com/i,
            /icon|font|typograph|color.?palette|illustration/i,
            /ui.?design|ux.?design|motion.?design|graphic/i,
          ],
          "뉴스" => [
            /medium\.com|dev\.to|hashnode\.com|producthunt\.com/i,
            /reddit\.com|hackernews\.ycombinator|lobste\.rs/i,
            /twitter\.com|x\.com|linkedin\.com/i,
            /newsletter|blog|rss|tech.?crunch|venturebeat/i,
          ],
          "튜토리얼" => [
            /scrimba\.com|egghead\.io|coursera\.org|udemy\.com/i,
            /tutorial|course|guide|how.?to|learn|getting.?started/i,
            /cheatsheet|quickstart|example|demo|sandbox|playground/i,
          ],
        }.freeze

        TAG_CATEGORIES = {
          "AI에이전트" => %w[mcp agent multiagent crewai langchain llamaindex orchestrator rag vector],
          "AI코딩" => %w[cursor windsurf copilot codex claude-code coding-agent vibe-coding],
          "AI모델" => %w[llm qwen llama kimi mistral ollama vllm embedding fine-tuning benchmark model],
          "프론트엔드" => %w[react vue svelte nextjs tailwind css ui component design-system],
          "백엔드" => %w[rails django api graphql microservice redis cache],
          "DevOps" => %w[docker kubernetes terraform ci-cd deploy monitoring prometheus grafana],
          "데이터베이스" => %w[postgresql mysql sqlite mongodb elasticsearch database sql nosql],
          "보안" => %w[security owasp encryption authentication vulnerability exploit],
          "디자인" => %w[ui-design ux icon font illustration motion],
          "뉴스" => %w[news blog newsletter community hackathon],
          "튜토리얼" => %w[tutorial guide howto course cheatsheet],
        }.freeze

        def self.call(url, content_type = nil, text: nil)
          return "기타" unless url.is_a?(String) && url.present?

          # YouTube는 튜토리얼 우선
          if content_type == "youtube" || url.match?(/\Ahttps?:\/\/(www\.)?youtube\.com\//i)
            return detect_youtube_category(url, text: text)
          end

          # Twitter/X는 뉴스
          return "뉴스" if content_type == "twitter"

          # GitHub
          if content_type == "github" || url.match?(/\Ahttps?:\/\/(www\.)?github\.com\//i)
            return detect_github_category(url, text: text)
          end

          # 일반 웹페이지 — URL + 텍스트 모두 검색
          combined = "#{url} #{text}".to_s
          detect_from_text(combined)
        end

        private_class_method def self.detect_youtube_category(url, text:)
          # 텍스트 기반 분류 시도 (태그/요약)
          return "AI에이전트" if text&.match?(/agent|multiagent|mcp|orchestrat/i)
          return "AI코딩" if text&.match?(/cursor|windsurf|copilot|codex|claude.?code/i)
          return "AI모델" if text&.match?(/llm|qwen|llama|kimi|model|hugging.?face/i)
          return "DevOps" if text&.match?(/docker|kubernetes|terraform|deploy|ci.?cd/i)
          return "프론트엔드" if text&.match?(/react|vue|svelte|tailwind|css|ui/i)
          return "데이터베이스" if text&.match?(/postgres|mysql|sqlite|redis|database/i)
          return "보안" if text&.match?(/security|owasp|vulnerabilit|exploit/i)
          return "디자인" if text&.match?(/figma|ui.?design|ux|illustration/i)
          return "뉴스" if text&.match?(/news|trending| roundup|review|comparison/i)
          "튜토리얼" # YouTube 기본값
        end

        private_class_method def self.detect_github_category(url, text:)
          path = url.downcase

          # AI/ML
          return "AI에이전트" if path.match?(/langchain|llamaindex|crewai|autogen|multiagent|mcp/i)
          return "AI코딩" if path.match?(/cursor|copilot|codex|claude.?code|coding.?agent|vibe.?coding/i)
          return "AI모델" if path.match?(/transformers|ollama|vllm|hugging.?face|llama|qwen|kimi/i)
          return "프론트엔드" if path.match?(/react|vue|svelte|tailwind|ui.?kit|design.?system/i)
          return "DevOps" if path.match?(/docker|kubernetes|terraform|ansible|ci\/cd|argocd/i)
          return "데이터베이스" if path.match?(/postgres|mysql|sqlite|redis|elastic|meili/i)
          return "보안" if path.match?(/security|auth|encrypt|firewall|pentest/i)

          # 텍스트 기반 추가 분류
          return "AI에이전트" if text&.match?(/agent|multiagent|orchestrat/i)
          return "AI코딩" if text&.match?(/coding.?agent|code.?generation|ai.?assistant/i)
          return "AI모델" if text&.match?(/llm|model.?weight|inference|embedding/i)

          "기타"
        end

        private_class_method def self.detect_from_text(combined)
          CATEGORY_PATTERNS.each do |category, patterns|
            patterns.each do |pattern|
              return category if combined.match?(pattern)
            end
          end

          # 태그 기반 추가 분류
          TAG_CATEGORIES.each do |category, tags|
            return category if tags.any? { |tag| combined.match?(/\b#{Regexp.escape(tag)}/i) }
          end

          "기타"
        end
      end
    end
  end
end
