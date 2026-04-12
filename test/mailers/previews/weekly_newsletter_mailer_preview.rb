class WeeklyNewsletterMailerPreview < ActionMailer::Preview
  def digest
    digest_data = {
      date: I18n.l(Date.today, format: :long),
      favorites_count: 5,
      favorites: [
        {
          title: "Ruby on Rails Guide",
          url: "https://guides.rubyonrails.org",
          summary: "Complete guide to Rails development",
          tags: ["rails", "ruby", "web"],
          created_at: I18n.l(1.day.ago, format: :short)
        }
      ],
      top_tags: ["rails", "ruby", "web", "programming"]
    }

    WeeklyNewsletterMailer.digest(digest_data)
  end
end
