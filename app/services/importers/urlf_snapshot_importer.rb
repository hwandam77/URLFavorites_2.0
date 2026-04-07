module Importers
  class UrlfSnapshotImporter
    def self.call(db_path)
      new(db_path).call
    end

    def initialize(db_path)
      @db_path = db_path
    end

    def call
      imported = 0
      skipped = 0

      db = SQLite3::Database.new(@db_path, readonly: true)
      db.results_as_hash = true

      db.execute("SELECT url, title, created_at FROM bookmarks").each do |row|
        url = UrlNormalizer.call(row["url"].to_s)
        next if url.blank?

        if Favorite.exists?(url: url)
          skipped += 1
          next
        end

        content_type = UrlTypeDetector.call(url)
        Favorite.create!(
          url: url,
          title: row["title"].presence || url,
          content_type: content_type,
          status: "pending",
          created_at: row["created_at"]
        )
        imported += 1
      end

      db.close

      { imported: imported, skipped: skipped }
    end
  end
end
