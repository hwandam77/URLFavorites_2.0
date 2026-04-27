namespace :urlf do
  desc "Import bookmarks from old urlf SQLite snapshot"
  task :import, [ :db_path ] => :environment do |_t, args|
    db_path = args[:db_path]
    abort "Usage: bin/rails urlf:import[/path/to/urlf.sqlite3]" if db_path.blank?
    abort "File not found: #{db_path}" unless File.exist?(db_path)

    puts "Importing from #{db_path}..."
    result = Importers::UrlfSnapshotImporter.call(db_path)
    puts "Done. Imported: #{result[:imported]}, Skipped: #{result[:skipped]}"
  end
end
