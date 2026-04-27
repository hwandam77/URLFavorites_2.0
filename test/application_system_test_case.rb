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
end
