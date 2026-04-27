# frozen_string_literal: true

require "test_helper"

class UrlFavoritesBootTest < ActiveSupport::TestCase
  test "UrlFavorites 네임스페이스가 로드된다" do
    assert_equal "UrlFavorites", UrlFavorites.name
  end
end
