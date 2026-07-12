class WeeklyNewsletterMailer < ApplicationMailer
  default from: ENV["NEWSLETTER_FROM"] || "noreply@urlfavorites.local"

  def digest(digest_data)
    @digest = digest_data
    @user_email = ENV["NEWSLETTER_TO"] || "hwandam@gmail.com"

    mail to: @user_email,
         subject: "[URLFavorites] #{@digest[:favorites_count]}개의 저장된 링크 주간 요약"
  end
end
