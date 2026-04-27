module UrlFavorites
  module UseCases
    module Newsletter
      class SendWeeklyNewsletter
        def self.call
          recent_favorites = UrlFavorites::UseCases::Search::FavoriteSearch.call(
            status: "done",
            sort: "recent"
          ).where("created_at > ?", 7.days.ago).to_a

          return if recent_favorites.empty?
          return if recent_favorites.count < 3

          digest = build_digest(recent_favorites)
          WeeklyNewsletterMailer.digest(digest).deliver_later
        end

        def self.build_digest(favorites)
          {
            date: I18n.l(Date.today, format: :long),
            favorites_count: favorites.count,
            favorites: favorites.map { |f| format_favorite(f) },
            top_tags: extract_top_tags(favorites)
          }
        end

        def self.format_favorite(favorite)
          {
            title: favorite.title.presence || favorite.url,
            url: favorite.url,
            summary: favorite.analysis&.summary,
            tags: favorite.analysis&.tags || [],
            created_at: I18n.l(favorite.created_at, format: :short)
          }
        end

        def self.extract_top_tags(favorites)
          all_tags = favorites.flat_map { |f| f.analysis&.tags || [] }
          all_tags
            .group_by(&:itself)
            .transform_values(&:count)
            .sort_by { |_, count| -count }
            .first(10)
            .map(&:first)
        end
      end
    end
  end
end
