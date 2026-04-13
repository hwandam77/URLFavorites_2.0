class Analysis < ApplicationRecord
  belongs_to :favorite

  serialize :key_points, coder: JSON
  serialize :tags, coder: JSON

  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true

  def parsed_tags
    tags.is_a?(Array) ? tags : []
  end

  def parsed_key_points
    return [] unless key_points

    if key_points.is_a?(Array)
      key_points.map { |kp| kp.is_a?(Hash) ? kp : { "point" => kp.to_s } }
    else
      []
    end
  rescue JSON::ParserError
    []
  end
end
