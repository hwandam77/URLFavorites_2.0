class Analysis < ApplicationRecord
  belongs_to :favorite

  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true
end
