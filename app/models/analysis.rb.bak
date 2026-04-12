class Analysis < ApplicationRecord
  belongs_to :favorite

  serialize :key_points, coder: JSON
  serialize :tags, coder: JSON

  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true
end
