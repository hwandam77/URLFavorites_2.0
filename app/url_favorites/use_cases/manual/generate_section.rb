# frozen_string_literal: true

require Rails.root.join("app/url_favorites/integrations/llama_server/client").to_s

module UrlFavorites
  module UseCases
    module Manual
      class GenerateSection
        SYSTEM_PROMPT = <<~PROMPT
          당신은 한국어 온보딩 매뉴얼의 섹션 하나를 작성하는 전문 필자다.
          형식 요건 (엄격히 준수):
          - markdown으로 작성하고, 섹션 제목은 반드시 `##`로 시작한다.
          - 분량은 2,500~3,500자.
          - 용어 박스 2개 이상, 일상 비유 1개 이상을 포함한다. 원문에 함정이나 주의점이 있으면 주의 박스를 포함한다.
          - 박스 라벨 표기는 반드시 아래 형식 그대로 사용한다. 라벨에 다른 단어를 붙이지 않는다 (예: `> **용어 API**` 금지):
            > **용어** 용어명: 설명...
            > **비유** 비유 설명...
            > **주의** 주의 내용...
          - 원문에 근거 없는 사실은 쓰지 않는다. 추측이 필요하면 추측임을 명시한다.
          - 한국어로 서술하고, 코드·명령어·고유명사는 원문 표기를 유지한다.
        PROMPT

        def self.call(analysis_id:, position:, analysis_snapshot:)
          analysis = ::Analysis.find_by(id: analysis_id)
          section = analysis&.analysis_sections&.find_by(position: position)
          unless section
            Rails.logger.info("[Manual::GenerateSection] skip section_missing analysis=#{analysis_id} position=#{position}")
            return
          end

          if section.body.present?
            Rails.logger.info("[Manual::GenerateSection] skip already_generated section=#{section.id}")
            return
          end

          if analysis.updated_at.to_f != analysis_snapshot
            Rails.logger.info("[Manual::GenerateSection] skip snapshot_mismatch section=#{section.id}")
            return
          end

          favorite = analysis.favorite
          raw_content = favorite.raw_content.presence || analysis.raw_content
          other_headings = analysis.analysis_sections.where.not(position: position).pluck(:heading)

          user = <<~USER
            섹션 제목: #{section.heading}
            이 섹션의 핵심 포인트: #{section.focus}
            다른 섹션 제목 (이 주제들과 중복 서술 금지): #{other_headings.join(", ")}

            원문:
            #{raw_content}
          USER

          text, backend_model = UrlFavorites::Integrations::LlamaServer::Client.complete(
            system: SYSTEM_PROMPT,
            user: user,
            backend_role: "fast"
          )

          section.update!(body: text, backend_model: backend_model)
          favorite.broadcast_refresh_to(:favorites)
        end
      end
    end
  end
end
