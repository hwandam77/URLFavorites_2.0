# frozen_string_literal: true

module UrlFavorites
  module Domain
    module Analysis
      class BackendRouter
        LONG_CONTENT_THRESHOLD = 6_000
        LONG_CONTENT_TYPES = %w[youtube twitter].freeze
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
