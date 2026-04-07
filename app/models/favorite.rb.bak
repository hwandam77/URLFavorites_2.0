class Favorite < ApplicationRecord
  has_one :analysis, dependent: :destroy
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  validates :url, presence: true, uniqueness: true
  validates :content_type, inclusion: { in: %w[webpage youtube] }
  validates :status, inclusion: { in: %w[pending analyzing done failed] }
end
