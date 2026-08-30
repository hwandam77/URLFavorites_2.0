# frozen_string_literal: true

require "test_helper"
require Rails.root.join("app/url_favorites/use_cases/analysis/run_analysis").to_s

class GithubLinkExtractionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "마크다운 링크의 후행 괄호·문장부호를 제거하고 발주한다" do
    owner = "owner-#{SecureRandom.hex(4)}"
    parent = Favorite.create!(url: "https://github.com/#{owner}/parent", status: "done", content_type: "github")
    detail = <<~MD
      관련 리포: [boop](https://github.com/#{owner}/boop) 와
      - https://github.com/#{owner}/repo.
      - (https://github.com/#{owner}/proj)
    MD

    assert_difference -> { Favorite.where("url LIKE ?", "%#{owner}%").where.not(id: parent.id).count }, 3 do
      UrlFavorites::UseCases::Analysis::RunAnalysis.send(
        :enqueue_github_links_from_analysis, parent.id, detail
      )
    end

    urls = Favorite.where("url LIKE ?", "%#{owner}%").where.not(id: parent.id).pluck(:url)
    assert urls.include?("https://github.com/#{owner}/boop"), "후행 ) 제거: #{urls.inspect}"
    assert urls.include?("https://github.com/#{owner}/repo"), "후행 . 제거"
    assert urls.include?("https://github.com/#{owner}/proj"), "마크다운 괄호 링크"
    assert_equal %w[pending pending pending], Favorite.where("url LIKE ?", "%#{owner}%").where.not(id: parent.id).order(:url).pluck(:status), "발주 대기 상태"
  end
end
