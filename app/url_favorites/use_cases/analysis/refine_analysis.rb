# frozen_string_literal: true

require Rails.root.join("app/url_favorites/domain/analysis").to_s
require Rails.root.join("app/url_favorites/domain/analysis/prompt_style").to_s
require Rails.root.join("app/url_favorites/use_cases/analysis/run_analysis").to_s

module UrlFavorites
  module UseCases
    module Analysis
      class RefineAnalysis
        # heavy(13 tok/s) 가 받는 입력량을 본문 상한 상향(20,000자) 이전 수준으로 고정 — 그대로 넣으면 Net::ReadTimeout 회귀
        REFINE_INPUT_LIMIT = 8_000

        def self.call(favorite_id:, analysis_style:, analysis_snapshot:)
          favorite = Favorite.find_by(id: favorite_id)
          if favorite.nil?
            Rails.logger.info("[RefineAnalysis] skip favorite_missing id=#{favorite_id}")
            return
          end

          analysis = favorite.analysis
          raw_content = favorite.raw_content.presence || analysis&.raw_content
          if favorite.status != "done" || analysis.nil? || raw_content.blank?
            Rails.logger.info("[RefineAnalysis] skip preconditions id=#{favorite_id}")
            return
          end

          # 멱등 후처리 재실행: CAS 커밋 후 후처리에서 죽은 경우 복구
          if analysis.analysis_tier == "heavy"
            Rails.logger.info("[RefineAnalysis] idempotent postprocess id=#{favorite_id}")
            ReindexFavoriteJob.perform_later(favorite.id)
            favorite.broadcast_refresh_to(:favorites)
            return
          end

          if analysis.updated_at.to_f != analysis_snapshot
            Rails.logger.info("[RefineAnalysis] skip snapshot_mismatch id=#{favorite_id}")
            return
          end

          style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)

          llm_input = raw_content[0...REFINE_INPUT_LIMIT]

          # LLM 호출은 트랜잭션/락 밖
          result = UrlFavorites::Integrations::LlamaServer::Client.call(
            llm_input,
            type: favorite.content_type,
            analysis_style: style,
            content_length: llm_input.length,
            backend_role: "heavy"
          )

          unless result[:used_backend_role].to_s == "heavy"
            raise UrlFavorites::Integrations::LlamaServer::Client::ServerError,
              "heavy backend unavailable (got #{result[:used_backend_role].inspect}); refusing fast overwrite"
          end

          committed = false
          ActiveRecord::Base.transaction do
            favorite.reload
            analysis = favorite.analysis
            analysis&.reload

            if favorite.status != "done" || analysis.nil? || analysis.analysis_tier == "heavy" ||
                analysis.updated_at.to_f != analysis_snapshot
              Rails.logger.info("[RefineAnalysis] skip cas_failed id=#{favorite_id}")
              next
            end

            RunAnalysis.upsert_analysis!(
              favorite,
              raw_content,
              result,
              analysis_style: style,
              analysis_tier: "heavy",
              model_used: result[:used_backend_model]
            )

            favorite.update!(
              category: UrlFavorites::Domain::Urls::CategoryDetector.call(
                favorite.url,
                favorite.content_type,
                text: "#{favorite.title} #{Array(result[:tags]).join(" ")}"
              )
            )
            committed = true
          end

          return unless committed

          ReindexFavoriteJob.perform_later(favorite.id)
          favorite.broadcast_refresh_to(:favorites)
        end
      end
    end
  end
end
