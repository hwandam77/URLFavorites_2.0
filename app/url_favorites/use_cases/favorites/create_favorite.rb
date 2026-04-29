module UrlFavorites
  module UseCases
    module Favorites
      class CreateFavorite
        def self.call(url:)
          normalized = UrlFavorites::Domain::Urls::Normalizer.call(url)
          unless UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(normalized)
            raise UrlFavorites::Domain::Errors::UnsafeUrl, "Unsafe URL"
          end

          existing = Favorite.find_by(url: normalized)
          if existing
            enqueue_analysis_if_needed(existing)
            existing.reload

            return UrlFavorites::UseCases::Result.new(ok: true, value: { favorite: existing, created: false })
          end

          content_type = UrlFavorites::Domain::Urls::TypeDetector.call(normalized)
          favorite = Favorite.create!(
            url: normalized,
            title: normalized,
            content_type: content_type,
            status: "pending",
            category: UrlFavorites::Domain::Urls::CategoryDetector.call(normalized, content_type)
          )

          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: favorite.id)
          favorite.reload

          UrlFavorites::UseCases::Result.new(ok: true, value: { favorite: favorite, created: true })
        end

        def self.enqueue_analysis_if_needed(favorite)
          return if favorite.analyzing?
          return if favorite.done? && favorite.analysis.present?

          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: favorite.id)
        end
      end
    end
  end
end
