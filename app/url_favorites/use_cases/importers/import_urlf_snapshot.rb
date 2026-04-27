module UrlFavorites
  module UseCases
    module Importers
      class ImportUrlfSnapshot
        def self.call(db_path)
          new(db_path).call
        end

        def initialize(db_path)
          @reader = UrlFavorites::Integrations::Importers::UrlfSnapshot::Reader.new(db_path)
        end

        def call
          imported = 0
          skipped = 0

          @reader.each_bookmark do |row|
            url = UrlFavorites::Domain::Urls::Normalizer.call(row["url"].to_s)
            next if url.blank?
            next unless UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(url)

            if Favorite.exists?(url: url)
              skipped += 1
              next
            end

            content_type = UrlFavorites::Domain::Urls::TypeDetector.call(url)
            Favorite.create!(
              url: url,
              title: row["title"].presence || url,
              content_type: content_type,
              status: "pending",
              category: UrlFavorites::Domain::Urls::CategoryDetector.call(url, content_type),
              created_at: row["created_at"]
            )
            imported += 1
          end

          { imported: imported, skipped: skipped }
        end
      end
    end
  end
end
