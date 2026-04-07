# test/controllers/favorite_notes_controller_test.rb
require 'test_helper'

class FavoriteNotesControllerTest < ActionDispatch::IntegrationTest
  test "PATCH /favorites/:favorite_id/note updates note" do
    fav = Favorite.create!(title: "Note Test", url: "https://example.com/note", content_type: "webpage", status: "done")
    patch favorite_note_url(fav), params: { favorite: { note: "My personal note" } }
    assert_redirected_to favorite_url(fav)
    fav.reload
    assert_equal "My personal note", fav.note
  end

  test "PATCH /favorites/:favorite_id/note with blank note clears it" do
    fav = Favorite.create!(title: "Clear Note", url: "https://example.com/clear", content_type: "webpage", status: "done", note: "Old note")
    patch favorite_note_url(fav), params: { favorite: { note: "" } }
    assert_redirected_to favorite_url(fav)
    fav.reload
    assert_equal "", fav.note
  end

  test "PATCH /favorites/:favorite_id/note triggers reindex" do
    fav = Favorite.create!(title: "Reindex Note", url: "https://example.com/reindex", content_type: "webpage", status: "done")
    FavoriteSearchIndexer.reindex_all
    patch favorite_note_url(fav), params: { favorite: { note: "Updated note" } }
    fav.reload
    assert_equal "Updated note", fav.note
  end
end
