# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Analysis
      # vLLM 복구 후 LLM 장애로 실패한 분석을 자동 재발주한다.
      # HealthCheck가 정상일 때만 호출된다(잡이 이 조건을 지킨다).
      #
      # 선별 기준:
      # - failed 상태 + error_message 이 LLM 장애 시그니처(연결/타임아웃/응답 불량)인 것만.
      #   추출 실패(ExtractionError, yt-dlp 등)는 재발주해도 같은 이유로 실패하므로 제외.
      # - RECOVERY_BACKOFF 이전 실패는 제외 — 잡 자체 백오프(30/60/120s)와 모니터 주기가
      #   겹쳐 재발주 스탬피드가 나지 않게 하는 최소 안전 창.
      # - updated_at 이 STALE_ANALYZING 이상 지난 analyzing 상태도 회복 — 잡이 프로세스
      #   재시작 등으로 사라지면 analyzing 이 영원히 남는다. LLM 타임아웃(240s)보다 훨씬
      #   길어서 실행 중인 잡과 겹치지 않는다.
      #
      # raw_content 는 유지한다(AGENTS.md: 재시도 시 캐시된 본문 재사용) — LLM 장애로
      # 실패한 것이지 추출이 잘못된 게 아니다.
      class RecoverStalledAnalyses
        LLM_FAILURE_PATTERN = /
          LlamaServer::Client|
          All\ LLM\ backends\ failed|
          Net::ReadTimeout|
          Faraday|
          execution\ expired|
          Connection\ error|
          HTTP\ server\ error|
          Invalid\ (response\ envelope|JSON)
        /x.freeze

        RECOVERY_BACKOFF = 5.minutes
        STALE_ANALYZING = 30.minutes

        def self.call(now: Time.current)
          recovered_failed = Favorite
            .where(status: "failed")
            .where("updated_at < ?", now - RECOVERY_BACKOFF)
            .select { |f| f.error_message.to_s.match?(LLM_FAILURE_PATTERN) }

          stale_analyzing = Favorite
            .where(status: "analyzing")
            .where("updated_at < ?", now - STALE_ANALYZING)

          targets = (recovered_failed + stale_analyzing).uniq
          return Result.ok(value: { recovered: 0 }) if targets.empty?

          Rails.logger.info(
            "[RecoverStalledAnalyses] re-enqueueing #{targets.size} favorite(s): " \
            "failed=#{recovered_failed.size} stale_analyzing=#{stale_analyzing.size}"
          )

          targets.each do |favorite|
            UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(
              favorite_id: favorite.id,
              analysis_style: favorite.analysis&.analysis_style.presence ||
                UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT
            )
          rescue => e
            Rails.logger.error "[RecoverStalledAnalyses] favorite #{favorite.id} re-enqueue failed: #{e.message}"
          end

          Result.ok(value: { recovered: targets.size })
        end
      end
    end
  end
end
