require Rails.root.join("app/url_favorites/domain/analysis").to_s
require Rails.root.join("app/url_favorites/domain/analysis/prompt_style").to_s

module UrlFavorites
  module UseCases
    module Analysis
      class RunAnalysis
        DEFAULT_ANALYSIS_STYLE = "execution_brief"
        MAX_RETRIES = 3
        YOUTUBE_ANALYSIS_INPUT_LIMIT = 12_000
        YOUTUBE_TRANSCRIPT_PROMPT_LIMIT = 8_000
        YOUTUBE_TIMESTAMP_SAMPLE_LIMIT = 40

        def self.call(favorite_id:, analysis_style: DEFAULT_ANALYSIS_STYLE)
          favorite = Favorite.find(favorite_id)
          favorite.update!(status: "analyzing", error_message: nil)
          normalized_style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)

          extraction = nil
          raw_content = favorite.raw_content.presence
          if raw_content.blank?
            extraction = extract_content(favorite)
            raw_content = extraction[:raw_content]
            favorite.update!(raw_content: raw_content)
          end

          analysis_result = UrlFavorites::Integrations::LlamaServer::Client.call(
            raw_content,
            type: favorite.content_type,
            analysis_style: normalized_style,
            content_length: raw_content.length
          )

          used_model = analysis_result[:used_backend_model]

          # done 처리 후 reload 금지 — upsert 직후 snapshot (동시 세대 결합 방지)
          analysis = upsert_analysis!(
            favorite, raw_content, analysis_result,
            extraction: extraction,
            analysis_style: normalized_style,
            model_used: used_model
          )
          snapshot = analysis.updated_at.to_f

          favorite.update!(
            status: "done",
            category: UrlFavorites::Domain::Urls::CategoryDetector.call(
              favorite.url,
              favorite.content_type,
              text: "#{favorite.title} #{Array(analysis_result[:tags]).join(" ")}"
            ),
            retry_count: 0
          )

          # 분석 결과(제목·요약·태그)를 검색 인덱스에 반영 — 이것이 없으면 FTS 검색이 비어 있음
          ReindexFavoriteJob.perform_later(favorite.id)

          # detail_content 내 GitHub 링크 자동 추가+분석
          enqueue_github_links_from_analysis(favorite.id, analysis_result[:detail_content].to_s)

          # 후속 분석 발주
          if normalized_style == "onboarding_manual"
            PlanManualOutlineJob.perform_later(favorite.id, snapshot)
          elsif normalized_style == "link_roundup"
            PlanLinkRoundupJob.perform_later(favorite.id, snapshot)
          end
        rescue => e
          raise e unless favorite
          # 재분석 실패가 기존 완성 분석을 "실패"로 가리지 않도록, 완료본이 있으면 done 유지
          favorite.update!(
            status: favorite.analysis&.summary.present? ? "done" : "failed",
            retry_count: favorite.retry_count.to_i + 1,
            error_message: "#{e.class}: #{e.message}"
          )
          raise e if favorite.retry_count < MAX_RETRIES
        end

        def self.enqueue_github_links_from_analysis(favorite_id, detail_content)
          github_urls = detail_content.scan(%r{https?://github\.com/[^/\s"']+/[^/\s"']+(?::[^\s"']*)?/?}).map { |u| u.chomp('/') }.uniq
          return if github_urls.empty?

          # 부모 URL 제외 (이 분석 페이지 자체)
          parent_url = favorite_id ? Favorite.find_by(id: favorite_id)&.url : nil
          github_urls.reject! { |u| u == parent_url.chomp('/') }
          return if github_urls.empty?

          # 이미 존재하는 URL 제외
          existing = Favorite.where("url LIKE ?", "%github.com/").pluck(:url).map { |u| u.chomp('/') }
          github_urls -= existing

          # 없는 링크만 자동 추가+분석
          github_urls.first(20).each do |url|
            fav, created = Favorite.find_or_create_by(url: url) do |f|
              f.content_type = "github"
              f.status = "pending"
            end
            if created && fav.status == "pending"
              case fav.content_type
              when "github"
                AnalyzeWebpageAnalysisJob.set(wait: 5.seconds).perform_later(fav.id, "execution_brief")
              end
            end
          end
        end
        private_class_method :enqueue_github_links_from_analysis

        def self.extract_content(favorite)
          if favorite.content_type == "youtube"
            extraction = UrlFavorites::Integrations::Youtube::Extractor.call(favorite.url)
            favorite.update!(thumbnail_url: extraction[:thumbnail_url]) if extraction[:thumbnail_url].present?
            favorite.update!(title: extraction[:title]) if extraction[:title].present? && (favorite.title.blank? || favorite.title.to_s.start_with?("http://", "https://"))
            links = Array(extraction[:github_links]).reject(&:blank?)
            if links.any?
              favorite.update!(source_metadata: (favorite.source_metadata || {}).merge("github_links" => links))
            end
            extraction.merge(raw_content: youtube_analysis_input(extraction))
          elsif favorite.content_type == "twitter"
            extraction = UrlFavorites::Integrations::Twitter::Extractor.call(favorite.url)
            favorite.update!(thumbnail_url: extraction[:thumbnail_url]) if extraction[:thumbnail_url].present?
            favorite.update!(title: extraction[:title]) if extraction[:title].present? && (favorite.title.blank? || favorite.title.to_s.start_with?("http://", "https://"))
            extraction
          elsif favorite.content_type == "reddit"
            extraction = UrlFavorites::Integrations::Reddit::Extractor.call(favorite.url)
            favorite.update!(thumbnail_url: extraction[:thumbnail_url]) if extraction[:thumbnail_url].present?
            favorite.update!(title: extraction[:title]) if extraction[:title].present? && (favorite.title.blank? || favorite.title.to_s.start_with?("http://", "https://"))
            extraction
          elsif favorite.content_type == "github"
            extraction = UrlFavorites::Integrations::Webpage::Scraper.call(favorite.url)
            favorite.update!(title: extraction[:title]) if extraction[:title].present?
            meta = UrlFavorites::Integrations::Github::RepoClient.call(favorite.url)
            favorite.update!(source_metadata: meta) if meta
            { raw_content: [ extraction[:title], extraction[:body_text] ].compact.join(" ") }
          else
            extraction = UrlFavorites::Integrations::Webpage::Scraper.call(favorite.url)
            favorite.update!(title: extraction[:title]) if extraction[:title].present?
            { raw_content: [ extraction[:title], extraction[:body_text] ].compact.join(" ") }
          end
        end

        def self.youtube_analysis_input(extraction)
          content = <<~CONTENT
            Title: #{extraction[:title]}
            Description: #{extraction[:description]}
            Subtitle source: #{extraction[:subtitle_source].presence || "unknown"}
            Provided GitHub links:
            #{github_links_section(extraction[:github_links])}

            Analysis goal:
            이 YouTube 콘텐츠를 단순 요약하지 말고, 사용자가 바로 AI에게 지시하여 실행할 수 있는 AI 실행 브리프 수준으로 분석한다.
            핵심 주장, 실행 절차, 필요한 입력값, 주의사항, 재사용 가능한 프롬프트를 구분해서 추출한다.

            Required focus:
            - 영상의 목적과 대상 독자
            - 바로 실행 가능한 단계별 절차
            - 다른 AI에게 그대로 전달할 수 있는 지시문/프롬프트
            - 영상 내용에서 근거가 확인되는 제약, 전제, 리스크

            Transcript:
            #{truncated_youtube_transcript(extraction[:transcript])}

            Timestamped transcript sample:
            #{timestamped_transcript_section(extraction[:transcript_segments])}
          CONTENT

          content[0...YOUTUBE_ANALYSIS_INPUT_LIMIT]
        end

        def self.timestamped_transcript_section(segments)
          normalized_segments = Array(segments).first(YOUTUBE_TIMESTAMP_SAMPLE_LIMIT)
          return "- 미확인" if normalized_segments.empty?

          normalized_segments.map do |segment|
            timestamp = segment[:timestamp] || segment["timestamp"] || "00:00"
            text = segment[:text] || segment["text"]
            "- [#{timestamp}] #{text}"
          end.join("\n")
        end

        def self.truncated_youtube_transcript(transcript)
          transcript.to_s[0...YOUTUBE_TRANSCRIPT_PROMPT_LIMIT]
        end

        def self.github_links_section(links)
          normalized_links = Array(links).map(&:to_s).reject(&:blank?)
          return "- 미확인" if normalized_links.empty?

          normalized_links.map { |link| "- #{link}" }.join("\n")
        end

        def self.upsert_analysis!(favorite, raw_content, analysis_result, extraction: nil, analysis_style: DEFAULT_ANALYSIS_STYLE, model_used: nil)
          attrs = {
            raw_content: raw_content,
            summary: analysis_result[:summary],
            key_points: analysis_result[:key_points],
            tags: analysis_result[:tags],
            sentiment: analysis_result[:sentiment],
            detail_content: analysis_result[:detail_content],
            analysis_style: analysis_style,
            model_used: model_used
          }
          if extraction
            attrs[:transcript] = extraction[:transcript]
            attrs[:subtitle_source] = extraction[:subtitle_source]
            attrs[:transcript_segments] = extraction[:transcript_segments] if extraction[:transcript_segments]
          end

          if favorite.analysis
            favorite.analysis.update!(**attrs)
            favorite.analysis
          else
            favorite.create_analysis!(**attrs)
          end
        end
      end
    end
  end
end
