# test/application_system_test_case.rb
require "test_helper"

Capybara.register_driver(:rack_test) do |app|
  Capybara::RackTest::Driver.new(
    app,
    headers: {
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    }
  )
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  def sign_in_as(user = nil, password: AuthenticationTestHelpers::DEFAULT_PASSWORD)
    user ||= create_authenticated_user(password: password)

    visit new_session_url
    within "form[action='#{session_path}']" do
      fill_in "session[email_address]", with: user.email_address
      fill_in "session[password]", with: password
      click_button "로그인"
    end

    user
  end
end
