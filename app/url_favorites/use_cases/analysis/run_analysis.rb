module UrlFavorites
  module UseCases
    module Analysis
      class RunAnalysis
        def self.call(favorite_id:)
          favorite = Favorite.find(favorite_id)
          favorite.update!(status: "analyzing", error_message: nil)

          raw_content = favorite.raw_content.presence || extract_raw_content(favorite)
          favorite.update!(raw_content: raw_content) if favorite.raw_content.blank?

          analysis_result = UrlFavorites::Integrations::LlamaServer::Client.call(raw_content, type: favorite.content_type)

          upsert_analysis!(favorite, raw_content, analysis_result)

          favorite.update!(
            status: "done",
            category: UrlFavorites::Domain::Urls::CategoryDetector.call(favorite.url, favorite.content_type),
            retry_count: 0
          )
        rescue => e
          favorite.update!(
            status: "failed",
            retry_count: favorite.retry_count.to_i + 1,
            error_message: "#{e.class}: #{e.message}"
          )
          raise e if favorite.retry_count < UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
        end

        def self.extract_raw_content(favorite)
          if favorite.content_type == "youtube"
            r = UrlFavorites::Integrations::Youtube::Extractor.call(favorite.url)
            favorite.update!(thumbnail_url: r[:thumbnail_url]) if r[:thumbnail_url].present?
            favorite.update!(title: r[:title]) if r[:title].present? && (favorite.title.blank? || favorite.title.to_s.start_with?("http://", "https://"))
            youtube_analysis_input(r)
          else
            r = UrlFavorites::Integrations::Webpage::Scraper.call(favorite.url)
            favorite.update!(title: r[:title]) if r[:title].present?
            [ r[:title], r[:body_text] ].compact.join(" ")
          end
        end

        def self.youtube_analysis_input(extraction)
          <<~CONTENT
            Title: #{extraction[:title]}
            Description: #{extraction[:description]}
            Subtitle source: #{extraction[:subtitle_source].presence || "unknown"}

            Analysis goal:
            이 YouTube 콘텐츠를 단순 요약하지 말고, 사용자가 바로 AI에게 지시하여 실행할 수 있는 AI 실행 브리프 수준으로 분석한다.
            핵심 주장, 실행 절차, 필요한 입력값, 주의사항, 재사용 가능한 프롬프트를 구분해서 추출한다.

            Required focus:
            - 영상의 목적과 대상 독자
            - 바로 실행 가능한 단계별 절차
            - 다른 AI에게 그대로 전달할 수 있는 지시문/프롬프트
            - 영상 내용에서 근거가 확인되는 제약, 전제, 리스크

            Transcript:
            #{extraction[:transcript]}
          CONTENT
        end

        def self.upsert_analysis!(favorite, raw_content, analysis_result)
          attrs = {
            raw_content: raw_content,
            summary: analysis_result[:summary],
            key_points: analysis_result[:key_points],
            tags: analysis_result[:tags],
            sentiment: analysis_result[:sentiment],
            detail_content: analysis_result[:detail_content]
          }

          if favorite.analysis
            favorite.analysis.update!(**attrs)
          else
            favorite.create_analysis!(**attrs)
          end
        end
      end
    end
  end
end
