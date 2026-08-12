# LLM 기반 카테고리 재분류
# 이미 분석된 favorites(summary+tags)를 LLM에 보내 카테고리 분류
# 실행: rails runner scripts/reclassify_categories.rb

CATEGORIES = %w[
  AI에이전트 AI코딩 AI모델 프론트엔드 백엔드 DevOps
  데이터베이스 보안 디자인 뉴스 튜토리얼 기타
].freeze

CATEGORY_DESCRIPTIONS = {
  "AI에이전트" => "멀티에이전트, 오케스트레이션,自律 에이전트 프레임워크, MCP 서버",
  "AI코딩" => "AI 코딩 도구(Cursor, Windsurf, Codex), 프롬프트 엔지니어링, AI 보조 개발",
  "AI모델" => "LLM 모델(Qwen, Llama, Kimi), 임베딩, 파인튜닝, 벤치마크, 모델 배포",
  "프론트엔드" => "React, Vue, Svelte, UI 컴포넌트, CSS, 디자인 시스템, 웹 퍼포먼스",
  "백엔드" => "Rails, API, 마이크로서비스, 인증, 캐싱, 메시지 큐, 백엔드 아키텍처",
  "DevOps" => "CI/CD, Docker, Kubernetes, Terraform, 모니터링, 배포 자동화",
  "데이터베이스" => "PostgreSQL, Redis, SQLite, 벡터 DB, 검색 엔진, 데이터 파이프라인",
  "보안" => "웹 보안, 인증/인가, 암호화, 취약점, 프라이버시, 보안 도구",
  "디자인" => "UI/UX, 그래픽 디자인, 디자인 툴, 아이콘, 폰트, 모션 디자인",
  "뉴스" => "기술 뉴스, 커뮤니티, 블로그, 레터, 해커톤, 이벤트",
  "튜토리얼" => "학습 자료, 강좌, HOWTO, 가이드, 튜토리얼 영상",
  "기타" => "분류되지 않거나 범주에 맞지 않는 항목",
}.freeze

def build_prompt(favorites)
  items = favorites.map.with_index(1) do |f, idx|
    tags = (f.analysis&.parsed_tags || []).join(", ")
    <<~ITEM
      #{idx}. URL: #{f.url}
         타입: #{f.content_type}
         제목: #{f.title || "(없음)"}
         요약: #{f.analysis&.summary || "(없음)"}
         태그: #{tags || "(없음)"}
    ITEM
  end.join("\n")

  <<~PROMPT
    당신은 기술 북마크 분류 전문가입니다.
    다음 #{favorites.size}개의 북마크를 분야별로 분류해주세요.

    사용 가능한 카테고리 (번호만 답하세요):
    #{CATEGORIES.each_with_index.map { |c, i| "#{i + 1}. #{c} — #{CATEGORY_DESCRIPTIONS[c]}" }.join("\n")}

    분류 대상:
    #{items}

    응답 형식 (JSON 배열, 번호만):
    [1, 5, 3, ...]  ← 각 번호는 위 카테고리 번호에 해당
    정확히 #{favorites.size}개의 숫자를 답하세요.
  PROMPT
end

def run
  batch_size = 20
  done = 0
  failed = 0

  # 재분류 대상: 분석 완료되지만 기존 카테고리인 것들
  old_categories = %w[기타 튜토리얼 개발도구 AI모델 AI에이전트 AI코딩 뉴스/커뮤니티]
  targets = Favorite.joins(:analysis)
                     .where(favorites: { status: "done" })
                     .where(favorites: { category: old_categories })
                     .order(:id)
                     .to_a

  puts "Total to reclassify: #{targets.size}"

  # 이미 새 카테고리로 분류된건 제외
  targets.reject! { |f| CATEGORIES.include?(f.category) && f.category != "기타" }

  # 배치로 처리
  targets.each_slice(batch_size) do |batch|
    puts "\n[Batch] #{batch.size} items (id #{batch.first.id} ~ #{batch.last.id})"

    begin
      result = UrlFavorites::Integrations::LlamaServer::Client.complete(
        system: "You are a technical bookmark classifier. Respond with valid JSON only.",
        user: build_prompt(batch),
        backend_role: nil,
        timeout: 120
      )
      text, _model = result

      json_str = text.strip
      json_str = json_str.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
      parsed = JSON.parse(json_str)

      # LLM이 [1,2,3] 또는 {"classifications":[...]} 또는 {"categories":[...]} 형식 모두 허용
      indices = if parsed.is_a?(Array)
        parsed
      elsif parsed.is_a?(Hash)
        parsed.values.first
      else
        nil
      end

      if indices.is_a?(Array) && indices.size == batch.size
        batch.each_with_index do |f, i|
          new_category = CATEGORIES[indices[i] - 1] || "기타"
          if CATEGORIES.include?(new_category)
            f.update!(category: new_category)
            puts "  #{f.id}: #{f.category} → #{new_category}"
          else
            puts "  #{f.id}: invalid index #{indices[i]}, keeping #{f.category}"
          end
        end
        done += batch.size
      else
        puts "  ERROR: expected array of #{batch.size}, got #{indices.inspect}"
        failed += batch.size
      end
    rescue => e
      puts "  ERROR: #{e.message}"
      failed += batch.size
    end

    # 배치 사이에 잠시 대기
    sleep 1
  end

  puts "\n=== Done ==="
  puts "Reclassified: #{done}"
  puts "Failed: #{failed}"
end

run
