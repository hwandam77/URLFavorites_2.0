class Collection < ApplicationRecord
  has_many :collection_memberships, dependent: :destroy
  has_many :favorites, through: :collection_memberships

  validates :name, presence: true, uniqueness: true
end
