require "test_helper"

class WeeklyNewsletterMailerTest < ActionMailer::TestCase
  test "digest email renders correctly" do
    digest_data = {
      date: "2026년 4월 13일",
      favorites_count: 2,
      favorites: [
        {
          title: "Test Article",
          url: "https://example.com/test",
          summary: "Test summary",
          tags: ["test"],
          created_at: "04/13"
        },
        {
          title: "Another Article",
          url: "https://example.com/another",
          summary: "Another summary",
          tags: ["sample"],
          created_at: "04/12"
        }
      ],
      top_tags: ["test", "sample"]
    }

    email = WeeklyNewsletterMailer.digest(digest_data)

    assert_emails 1 do
      email.deliver_now
    end

    assert_includes email.subject, "저장된 링크"
    assert_includes email.subject, "2개"
    assert_match(/주간 링크 큐레이션/, email.html_part&.body&.raw_source || email.body.to_s)
    assert_match(/Test Article/, email.html_part&.body&.raw_source || email.body.to_s)
  end
end
