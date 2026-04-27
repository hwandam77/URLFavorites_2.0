require "test_helper"

class WeeklyNewsletterJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    ActionMailer::Base.deliveries.clear
    # Clean up any existing test data
    Favorite.where("url LIKE ?", "%example.com/article-%").destroy_all
  end

  def teardown
    # Clean up after test
    Favorite.where("url LIKE ?", "%example.com/article-%").destroy_all
  end

  test "perform sends email when 3+ recent favorites" do
    3.times do |i|
      fav = Favorite.create!(
        url: "https://example.com/send-#{i}-#{SecureRandom.hex(4)}",
        content_type: "webpage",
        status: "done",
        created_at: Time.current
      )
      fav.create_analysis!(summary: "Test summary #{i}", tags: ["test"])
    end

    job = WeeklyNewsletterJob.new
    perform_enqueued_jobs { job.perform }

    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test "perform does not send email when fewer than 3 recent favorites" do
    fav = Favorite.create!(
      url: "https://example.com/no-send-#{SecureRandom.hex(4)}",
      content_type: "webpage",
      status: "done",
      created_at: Time.current
    )
    fav.create_analysis!(summary: "Test summary", tags: ["test"])

    job = WeeklyNewsletterJob.new
    job.perform

    assert_equal 0, ActionMailer::Base.deliveries.count
  end

  test "perform does not send email when 0 recent favorites" do
    job = WeeklyNewsletterJob.new
    job.perform

    assert_equal 0, ActionMailer::Base.deliveries.count
  end

  test "does not send when fewer than 3 recent favorites" do
    # Only 2 favorites created in setup, should not send
    assert_difference "ActionMailer::Base.deliveries.count", 0 do
      WeeklyNewsletterJob.perform_now
    end
  end

  test "handles nil summary gracefully" do
    fav = Favorite.create!(url: "https://example.com/nil-summary", content_type: "webpage", status: "done")
    fav.create_analysis!(summary: nil, tags: [])

    assert_nothing_raised do
      digest = UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.build_digest([fav])
      assert_nil digest[:favorites][0][:summary]
      assert_equal [], digest[:favorites][0][:tags]
    end
  end

  test "build_digest formats favorites correctly" do
    test_url = "https://example.com/test-fixed-url"
    fav = Favorite.create!(
      url: test_url,
      content_type: "webpage",
      status: "done",
      title: "Test Title",
      created_at: Time.current
    )
    fav.create_analysis!(summary: "Test summary", tags: ["ruby", "rails"])

    digest = UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.build_digest([fav])

    assert_equal 1, digest[:favorites_count]
    assert_equal "Test Title", digest[:favorites].first[:title]
    assert_equal test_url, digest[:favorites].first[:url]
    assert_equal "Test summary", digest[:favorites].first[:summary]
    assert_equal ["ruby", "rails"], digest[:favorites].first[:tags]
  end
end
