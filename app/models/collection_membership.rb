class CollectionMembership < ApplicationRecord
  belongs_to :favorite
  belongs_to :collection

  validates :favorite_id, uniqueness: { scope: :collection_id }
end
