require "test_helper"

class WeeklyNewsletterJobTest < ActiveSupport::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
    # Clean up any existing test data
    Favorite.where("url LIKE ?", "%example.com/article-%").destroy_all
  end

  def teardown
    # Clean up after test
    Favorite.where("url LIKE ?", "%example.com/article-%").destroy_all
  end

  test "should_send returns true when 3+ recent favorites" do
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
    assert job.send(:should_send?)
  end

  test "should_send returns false when fewer than 3 recent favorites" do
    fav = Favorite.create!(
      url: "https://example.com/no-send-#{SecureRandom.hex(4)}",
      content_type: "webpage",
      status: "done",
      created_at: Time.current
    )
    fav.create_analysis!(summary: "Test summary", tags: ["test"])

    job = WeeklyNewsletterJob.new
    refute job.send(:should_send?)
  end

  test "should_send returns false when 0 recent favorites" do
    job = WeeklyNewsletterJob.new
    refute job.send(:should_send?)
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

    job = WeeklyNewsletterJob.new
    digest = job.send(:build_digest, [fav])

    assert_equal 1, digest[:favorites_count]
    assert_equal "Test Title", digest[:favorites].first[:title]
    assert_equal test_url, digest[:favorites].first[:url]
    assert_equal "Test summary", digest[:favorites].first[:summary]
    assert_equal ["ruby", "rails"], digest[:favorites].first[:tags]
  end
end
