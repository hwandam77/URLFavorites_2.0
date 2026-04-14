module UrlFavorites
  module Domain
    module Urls
      class CategoryDetector
        # URL/도메인 기반 카테고리 분류
        # 대분류: content_type (webpage/youtube/github)
        # 소분류: category (AI에이전트/AI코딩/튜토리얼/AI모델/개발도구/뉴스/커뮤니티/기타)

        CATEGORY_PATTERNS = {
          "AI에이전트" => [
            # 도메인 우선 매칭
            /langchain\.ai|llamaindex\.ai|crewai\.com|autogen\.ai/i,
            /claude\.ai|openai\.com\.agent|gemini\.google\.com|vertex\.ai/i,
            /mcp\.run|mcp\.iit|modelcontextprotocol\.github/i,
            /pinecone\.io|weaviate\.io|chroma\.dev|qdrant\.tech|milvus\.ai/i,
            /crewai\.co|multiagent\.ai|agentica\.ai/i,
            # 경로 매칭
            /langchain|llamaindex|crewai|autogen|multiagent|agent.?framework/i,
            /claude.?api|openai.?agent|gemini.?agent|mcp.?server/i,
            /agent.?loop|reasoning.?engine|autonomous.?agent/i,
            /pinecone|weaviate|chroma.?db|vector.?db|rag.?retrieval/i
          ],
          "AI코딩" => [
            # 도메인
            /cursor\.sh|windsurf\.ai|claude\.dev|nextjs\.ai|v0\.dev/i,
            /bolt\.diagrams\.net|replit\.com|lovable\.dev|devin\.ai/i,
            /github\.com\/.*copilot/i,
            # 경로
            /github\.copilot|cursor|windsurf|claude.?dev|nextjs.?ai/i,
            /v0\.dev|bolt\.new|replit|lovable|devin| SWE.?bench/i,
            /code.?generation|ai.?code.?review|automated.?refactor/i
          ],
          "튜토리얼" => [
            # 도메인
            /tutorial\.example|scrimba\.com|egghead\.io|coursera\.org/i,
            /udemy\.com|udacity\.com|khanacademy\.org|freecodecamp\.org/i,
            /docs\.readme\.io|guides\.github|iHerb\.com/i,
            /blog\.post|cheatsheet|quickstart/i,
            # 경로
            /tutorial|course|guide|how.?to|learn|getting.?started/i,
            /docs\.readme|blog\.post|cheatsheet|quickstart/i,
            /example|demo|sandbox|playground/i
          ],
          "AI모델" => [
            # 도메인
            /huggingface\.co|ollama\.ai|vllm\.github|anthropic\.com/i,
            /openai\.com|gptstore\.openai|chatgpt\.com|cohere\.ai/i,
            /mistral\.ai|qwen\.tongyi|deepseek\.ai|groq\.com/i,
            /lepton\.ai|replicate\.com|sAMBAmultiLLM/i,
            # 경로
            /hugging.?face|transformers|llama|gemini|claude|gpt|ollama/i,
            /model.?hub|pretrained|fine.?tuning|rlhf|llm.?benchmark/i,
            /mistral|qwen|deepseek|command[_-]?r|Yi.?34B|Starling/i
          ],
          "개발도구" => [
            # 도메인
            /github\.com|gitlab\.com|bitbucket\.org/i,
            /docker\.com|traefik\.io|kubernetes\.io|terraform\.io/i,
            /jetbrains\.com|neovim\.io|vim\.org|reddit\.com\/r\/vim/i,
            /postman\.com|insomnia\.rest|swagger\.io|openapi-generator/i,
            %r{argoproj|argocd|github/actions|github/pages}i,
            # 경로
            /github\.com\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]*\.git|gitlab|bitbucket/i,
            /docker|kubernetes|terraform|ansible|ci\/cd|pipeline/i,
            /vscode|jetbrains|vim|neovim|terminal|cli/i,
            /postman|insomnia|swagger|openapi|api.?design/i
          ],
          "뉴스/커뮤니티" => [
            # 도메인
            /medium\.com|dev\.to|hashnode\.com|newsletter\.producthunt/i,
            /reddit\.com|hackernews\.ycombinator|lobste\.rs/i,
            /twitter\.com|x\.com|linkedin\.com|discord\.gg/i,
            /arxiv\.org|papers\.withcode|research\.google|deepmind\.com/i,
            /feedly\.com|inoreader\.com|bloglovin|rss\./i,
            # 경로
            /newsletter|blog|rss|medium|dev\.to|hashnode/i,
            /reddit|hacker.?news|lobsters|product.?hunt/i,
            /twitter\.com|x\.com|linkedin|discord|slack\.com/i,
            /arxiv\.org|papers\.withcode|research\.google/i
          ]
        }.freeze

        def self.call(url, content_type = nil)
          return "기타" unless url.is_a?(String) && url.present?

          # YouTube는 튜토리얼 카테고리 우선
          if content_type == "youtube" || url.match?(/\Ahttps?:\/\/(www\.)?youtube\.com\/(watch|shorts|embed)/i)
            return detect_youtube_category(url)
          end

          # GitHub
          if content_type == "github" || url.match?(/\Ahttps?:\/\/(www\.)?github\.com\//i)
            return detect_github_category(url)
          end

          # 일반 웹페이지
          detect_web_category(url)
        end

        private_class_method def self.detect_youtube_category(url)
          # YouTube 채널/크리에이터 기반 분류
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

          "튜토리얼" # YouTube 기본값
        end

        private_class_method def self.detect_github_category(url)
          path = url.downcase

          # AI/ML 프레임워크
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
