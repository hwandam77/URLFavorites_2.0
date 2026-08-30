# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Authentication
      class UpdatePassword
        def self.call(user:, current_password:, password:, password_confirmation: nil, keep_session: nil)
          return Result.fail(error: :wrong_current_password) unless user.authenticate(current_password.to_s)

          # password_confirmation을 항상 다시 설정한다 — 생성 시점의 값이 남아 있으면
          # 새 암호와 불일치로 검증된다. nil이면 has_secure_password가 검증을 건너뛴다.
          user.password = password.to_s
          user.password_confirmation = password_confirmation.to_s.presence

          return Result.fail(error: :invalid_new_password) unless user.save

          # 암호 변경 후 현재 세션만 유지하고 나머지 세션은 무효화한다.
          user.sessions.where.not(id: keep_session&.id).destroy_all

          Result.ok(value: { user: user })
        end
      end
    end
  end
end
