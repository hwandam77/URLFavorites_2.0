class Session < ApplicationRecord
  belongs_to :user

  has_secure_token

  def self.find_by_token(token)
    find_by(token: token) if token.present?
  end
end
