require "sqlite3"

module UrlFavorites
  module Integrations
    module Importers
      module UrlfSnapshot
        class Reader
          def initialize(db_path)
            @db_path = db_path
          end

          def each_bookmark
            db = SQLite3::Database.new(@db_path, readonly: true)
            db.results_as_hash = true
            db.execute("SELECT url, title, created_at FROM bookmarks").each do |row|
              yield row
            end
          ensure
            db&.close
          end
        end
      end
    end
  end
end
