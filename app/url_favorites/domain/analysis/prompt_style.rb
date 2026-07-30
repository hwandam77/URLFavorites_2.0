module UrlFavorites
  module Domain
    module Analysis
      class PromptStyle
        DEFAULT = "execution_brief"
        OPTIONS = {
          "execution_brief" => "실행 브리프",
          "qna" => "Q&A",
          "tutorial" => "튜토리얼",
          "prompt_extract" => "프롬프트 추출",
          "onboarding_manual" => "온보딩 매뉴얼"
        }.freeze

        INSTRUCTIONS = {
          "execution_brief" => <<~TEXT,
            Focus on a professional AI execution brief.
            detail_content must prioritize reusable workflow, inputs, assumptions, risks, and a complete ready-to-use prompt.
          TEXT
          "qna" => <<~TEXT,
            Format detail_content as a Korean Q&A document.
            Include exactly three basic questions, two advanced questions, one common misconception, and follow-up topics.
            Every answer must stay grounded in the provided content.
          TEXT
          "tutorial" => <<~TEXT,
            Format detail_content as a Korean step-by-step tutorial.
            Include prerequisites, ordered steps, expected outputs, verification checks, and common failure points.
          TEXT
          "prompt_extract" => <<~TEXT,
            Format detail_content as reusable AI instructions only.
            Extract role, task, input format, output format, constraints, examples, and validation checklist.
            The result should be directly copyable into another AI session.
          TEXT
          "onboarding_manual" => <<~TEXT
            Summarize the content for first-time readers as a quick overview.
            detail_content stays short (3~5 paragraphs as usual); the full onboarding manual is generated separately in sections.
          TEXT
        }.freeze

        def self.normalize(value)
          key = value.to_s
          OPTIONS.key?(key) ? key : DEFAULT
        end

        def self.label(value)
          OPTIONS.fetch(normalize(value))
        end

        def self.instructions_for(value)
          INSTRUCTIONS.fetch(normalize(value))
        end
      end
    end
  end
end
