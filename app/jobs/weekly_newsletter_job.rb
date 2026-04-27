class WeeklyNewsletterJob < ApplicationJob
  queue_as :default

  def perform
    UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter.call
  end
end
