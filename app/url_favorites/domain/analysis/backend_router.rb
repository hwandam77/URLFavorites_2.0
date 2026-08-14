# frozen_string_literal: true
# ponytail: removed heavy/fast routing — single backend (Nexus vllm Qwen3.6-27B) since 2026-08-12

module UrlFavorites
  module Domain
    module Analysis
      class BackendRouter
        # Kept as constants for backward compatibility (refine_candidate? still references these).
        LONG_CONTENT_THRESHOLD = 6_000
        DETAILED_STYLES = %w[detail qna tutorial prompt_extract].freeze

        def self.call(_content_type:, _content_length:, _analysis_style: nil)
          %w[default]
        end
      end
    end
  end
end
