ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "securerandom"

module AuthenticationTestHelpers
  DEFAULT_PASSWORD = "password123"

  def create_authenticated_user(email_address: nil, password: DEFAULT_PASSWORD)
    User.create!(
      email_address: email_address || "user-#{SecureRandom.hex(6)}@example.com",
      password: password,
      password_confirmation: password
    )
  end

  def sign_in_as(user = nil, password: DEFAULT_PASSWORD)
    user ||= create_authenticated_user(password: password)

    post session_url, params: {
      session: {
        email_address: user.email_address,
        password: password
      }
    }

    user
  end
end

module ActiveSupport
  class TestCase
    # 지정된 작업자 수로 병렬로 테스트를 실행합니다
    parallelize(workers: :number_of_processors)

    # 알파벳 순서로 모든 테스트에 대해 test/fixtures/*.yml 의 모든 고정 데이터를 설정합니다.
    fixtures :all

    # 모든 테스트에서 사용할 수 있도록 추가 헬퍼 메서드를 여기에 추가합니다...
    include AuthenticationTestHelpers
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationTestHelpers
end
