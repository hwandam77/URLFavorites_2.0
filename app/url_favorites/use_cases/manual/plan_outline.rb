# frozen_string_literal: true

require Rails.root.join("app/url_favorites/integrations/llama_server/client").to_s

module UrlFavorites
  module UseCases
    module Manual
      class PlanOutline
        DEFAULT_OUTLINE = [
          [ "한줄요약", "원문 전체를 한두 문장으로 압축한 요약" ],
          [ "왜 필요한가", "이 콘텐츠가 다루는 문제와 필요성" ],
          [ "핵심 기능", "원문이 설명하는 핵심 기능과 개념" ],
          [ "장점", "원문에 근거한 강점과 이점" ],
          [ "함정·주의", "원문에 나오는 함정, 제약, 주의점" ],
          [ "활용 사례", "원문에 근거한 활용 방법과 사례" ],
          [ "판단 기준", "도입·사용 여부를 판단하는 체크리스트" ],
          [ "시작하기", "바로 시작하기 위한 첫 단계" ]
        ].freeze

        def self.call(favorite_id:, analysis_snapshot:)
          favorite = Favorite.find_by(id: favorite_id)
          unless favorite
            Rails.logger.info("[Manual::PlanOutline] skip favorite_missing id=#{favorite_id}")
            return
          end

          analysis = favorite.analysis
          raw_content = favorite.raw_content.presence || analysis&.raw_content
          if favorite.status != "done" || analysis.nil? || raw_content.blank?
            Rails.logger.info("[Manual::PlanOutline] skip preconditions id=#{favorite_id}")
            return
          end

          if analysis.updated_at.to_f != analysis_snapshot
            Rails.logger.info("[Manual::PlanOutline] skip snapshot_mismatch id=#{favorite_id}")
            return
          end

          sections = analysis.analysis_sections.to_a
          if sections.any?
            if sections.all? { |section| section.body.present? }
              Rails.logger.info("[Manual::PlanOutline] skip already_complete id=#{favorite_id}")
              return
            end
            # 중단된 생성의 재개: 부분 섹션을 이어붙이면 목차가 어긋나므로 전부 지우고 목차부터 다시 만든다
            analysis.analysis_sections.destroy_all
          end

          outline = generate_outline(favorite, raw_content)

          outline.each_with_index do |item, index|
            analysis.analysis_sections.create!(
              position: index + 1,
              heading: item[:heading],
              focus: item[:focus]
            )
          end

          outline.each_index do |index|
            GenerateManualSectionJob.perform_later(analysis.id, index + 1, analysis_snapshot)
          end
        end

        def self.generate_outline(favorite, raw_content)
          system = <<~PROMPT
            당신은 한국어 온보딩 매뉴얼의 목차를 설계하는 편집자다.
            주어진 원문의 성격에 맞는 섹션 8~10개 목차를 설계한다.
            출력은 JSON 배열 하나만 허용된다: [{"heading": "...", "focus": "..."}]
            - heading: 섹션 제목 (짧고 명확하게)
            - focus: 이 섹션에서 다룰 핵심 포인트 (생성 지시용)
            JSON 배열 외의 텍스트는 절대 출력하지 않는다.
          PROMPT
          user = "Title: #{favorite.title}\n\n원문:\n#{raw_content}"

          text, _model = UrlFavorites::Integrations::LlamaServer::Client.complete(
            system: system,
            user: user
          )
          parse_outline(text)
        end

        def self.parse_outline(text)
          items = JSON.parse(strip_code_fence(text))
          entries = outline_entries(items)
          entries.length >= 5 ? entries : default_entries
        rescue JSON::ParserError, TypeError
          default_entries
        end

        def self.outline_entries(items)
          return [] unless items.is_a?(Array)

          items.filter_map do |item|
            next unless item.is_a?(Hash)

            heading = (item["heading"] || item[:heading]).to_s.strip
            next if heading.blank?

            { heading: heading, focus: (item["focus"] || item[:focus]).to_s }
          end
        end

        def self.default_entries
          DEFAULT_OUTLINE.map { |heading, focus| { heading: heading, focus: focus } }
        end

        def self.strip_code_fence(text)
          trimmed = text.to_s.strip
          return trimmed unless trimmed.start_with?("```")

          trimmed = trimmed.sub(/\A```(?:json)?\s*/i, "")
          trimmed.sub(/\s*```\z/, "")
        end

        private_class_method(
          :generate_outline,
          :parse_outline,
          :outline_entries,
          :default_entries,
          :strip_code_fence
        )
      end
    end
  end
end
