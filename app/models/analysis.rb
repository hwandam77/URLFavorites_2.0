class Analysis < ApplicationRecord
  belongs_to :favorite
  has_many :analysis_sections, -> { order(:position) }, dependent: :destroy

  serialize :key_points, coder: JSON
  serialize :tags, coder: JSON
  serialize :transcript_segments, coder: JSON

  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true

  after_commit :broadcast_favorite_refresh

  def analysis_style_label
    UrlFavorites::Domain::Analysis::PromptStyle.label(analysis_style)
  end

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

  def parsed_transcript_segments
    return [] unless transcript_segments

    Array(transcript_segments).filter_map do |segment|
      next unless segment.is_a?(Hash)

      text = segment["text"].to_s.strip
      next if text.blank?

      {
        "start" => segment["start"].to_f,
        "duration" => segment["duration"].to_f,
        "text" => text,
        "timestamp" => segment["timestamp"].presence || self.class.format_timestamp(segment["start"].to_f)
      }
    end
  rescue JSON::ParserError
    []
  end

  def self.format_timestamp(seconds)
    total_seconds = seconds.to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    secs = total_seconds % 60

    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%02d:%02d", minutes, secs)
    end
  end

  private

  def broadcast_favorite_refresh
    favorite.broadcast_refresh_to favorite
  end
end
