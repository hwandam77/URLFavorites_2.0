class Favorite < ApplicationRecord
  has_one :analysis, dependent: :destroy
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  validates :url, presence: true, uniqueness: true
  validates :content_type, inclusion: { in: %w[webpage youtube] }
  validates :status, inclusion: { in: %w[pending analyzing done failed] }

  # Turbo Stream: 분석 완료/실패 시 자동으로 갱신
  after_update_commit -> {
    broadcast_replace_to :favorites
  }
end
