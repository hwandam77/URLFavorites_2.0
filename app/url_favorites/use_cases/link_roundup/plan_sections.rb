# frozen_string_literal: true

require Rails.root.join("app/url_favorites/integrations/github/repo_client").to_s

module UrlFavorites
  module UseCases
    module LinkRoundup
      class PlanSections
        MIN_LINKS = 3
        MAX_LINKS = 20

        def self.call(favorite_id:, analysis_snapshot:)
          favorite = Favorite.find_by(id: favorite_id)
          unless favorite
            Rails.logger.info("[LinkRoundup::PlanSections] skip favorite_missing id=#{favorite_id}")
            return
          end

          analysis = favorite.analysis
          if favorite.status != "done" || analysis.nil?
            Rails.logger.info("[LinkRoundup::PlanSections] skip preconditions id=#{favorite_id}")
            return
          end

          if analysis.updated_at.to_f != analysis_snapshot
            Rails.logger.info("[LinkRoundup::PlanSections] skip snapshot_mismatch id=#{favorite_id}")
            return
          end

          links = Array(favorite.source_metadata&.dig("github_links"))
          if links.length < MIN_LINKS
            Rails.logger.info("[LinkRoundup::PlanSections] skip too_few_links id=#{favorite_id} links=#{links.length}")
            return
          end
          total_links = links.length
          links = links.first(MAX_LINKS)
          if links.length < total_links
            Rails.logger.info("[LinkRoundup::PlanSections] truncated id=#{favorite_id} 원본 #{total_links}개 중 #{links.length}개 수록, #{total_links - links.length}개 생략")
          end

          sections = analysis.analysis_sections.to_a
          if sections.any?
            if sections.all? { |section| section.body.present? }
              Rails.logger.info("[LinkRoundup::PlanSections] skip already_complete id=#{favorite_id}")
              return
            end
            # 중단된 생성의 재개: 부분 섹션을 이어붙이면 목차가 어긋나므로 전부 지우고 목차부터 다시 만든다
            analysis.analysis_sections.destroy_all
          end

          repos = {}
          links.each_with_index do |url, index|
            meta = UrlFavorites::Integrations::Github::RepoClient.call(url)
            slug = meta&.dig("full_name").presence || slug_from_url(url) || url
            analysis.analysis_sections.create!(
              position: index + 1,
              heading: slug,
              focus: meta&.dig("description").presence || url
            )
            repos[slug] = meta if meta
          end

          favorite.update!(source_metadata: (favorite.source_metadata || {}).merge("repos" => repos))

          links.each_index do |index|
            GenerateManualSectionJob.perform_later(analysis.id, index + 1, analysis_snapshot)
          end
        end

        def self.slug_from_url(url)
          match = url.to_s.match(UrlFavorites::Integrations::Github::RepoClient::REPO_PATTERN)
          return nil unless match

          "#{match[1]}/#{match[2].sub(/\.git\z/i, "")}"
        end
        private_class_method :slug_from_url
      end
    end
  end
end
