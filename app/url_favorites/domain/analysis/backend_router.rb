# frozen_string_literal: true

module UrlFavorites
  module Domain
    module Analysis
      class BackendRouter
        LONG_CONTENT_THRESHOLD = 6_000
        # youtube 는 제외: heavy 40B 가 fast 35B(A3B MoE) 보다 5배 느려(~13 vs ~62 tok/s)
        # 긴 영상 분석에서 read timeout 이 간헐 발생했다. fast 가 안정적으로 빠르므로 fast-first 고정.
        LONG_CONTENT_TYPES = %w[twitter].freeze
        DETAILED_STYLES = %w[detail qna tutorial prompt_extract].freeze

        def self.call(content_type:, content_length:, analysis_style: nil)
          heavy_first = DETAILED_STYLES.include?(analysis_style.to_s) ||
            (LONG_CONTENT_TYPES.include?(content_type.to_s) && content_length.to_i >= LONG_CONTENT_THRESHOLD)

          heavy_first ? %w[heavy fast] : %w[fast heavy]
        end
      end
    end
  end
end
