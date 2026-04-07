require 'test_helper'
require 'sqlite3'

class Importers::UrlfSnapshotImporterTest < ActiveSupport::TestCase
  def setup
    @db_path = Rails.root.join("tmp", "test_urlf_snapshot_#{Process.pid}_#{SecureRandom.hex(4)}.sqlite3").to_s
    db = SQLite3::Database.new(@db_path)
    db.execute("CREATE TABLE IF NOT EXISTS bookmarks (id INTEGER PRIMARY KEY, url TEXT, title TEXT, created_at TEXT)")
    db.execute("INSERT INTO bookmarks (url, title, created_at) VALUES (?, ?, ?)", ["https://example.com/old1", "Old Bookmark 1", "2024-01-01 00:00:00"])
    db.execute("INSERT INTO bookmarks (url, title, created_at) VALUES (?, ?, ?)", ["https://example.com/old2", "Old Bookmark 2", "2024-02-01 00:00:00"])
    db.execute("INSERT INTO bookmarks (url, title, created_at) VALUES (?, ?, ?)", ["https://youtube.com/watch?v=old", "Old YouTube", "2024-03-01 00:00:00"])
    db.close
  end

  def teardown
    File.delete(@db_path) if File.exist?(@db_path)
  end

  test "imports bookmarks from old urlf database" do
    result = Importers::UrlfSnapshotImporter.call(@db_path)
    assert_equal 3, result[:imported]
    assert_equal 3, Favorite.count
  end

  test "detects content_type for youtube URLs" do
    Importers::UrlfSnapshotImporter.call(@db_path)
    yt = Favorite.find_by(url: "https://youtube.com/watch?v=old")
    assert_equal "youtube", yt.content_type
  end

  test "skips duplicate URLs on re-import" do
    Importers::UrlfSnapshotImporter.call(@db_path)
    result = Importers::UrlfSnapshotImporter.call(@db_path)
    assert_equal 0, result[:imported]
    assert_equal 3, result[:skipped]
    assert_equal 3, Favorite.count
  end

  test "is idempotent on repeated runs" do
    3.times { Importers::UrlfSnapshotImporter.call(@db_path) }
    assert_equal 3, Favorite.count
  end

  test "returns summary hash with imported and skipped counts" do
    result = Importers::UrlfSnapshotImporter.call(@db_path)
    assert_kind_of Hash, result
    assert result.key?(:imported)
    assert result.key?(:skipped)
  end
end
