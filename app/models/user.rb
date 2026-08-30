class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(email_address) { email_address.to_s.strip.downcase }

  validates :email_address,
    presence: true,
    uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  # 개인 앱 — 사용자 요청으로 최소 길이 8 → 6 (2026-08-31)
  validates :password, length: { minimum: 6 }, allow_nil: true
end
