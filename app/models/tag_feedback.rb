class TagFeedback < ApplicationRecord
  belongs_to :favorite

  # NOTE: user_id column exists for future multi-user support
  # but User model is not implemented yet, so no association

  serialize :original_tags, coder: JSON
  serialize :corrected_tags, coder: JSON

  validates :favorite_id, uniqueness: true
  validates :original_tags, presence: true
  validates :corrected_tags, presence: true

  # Returns tag corrections (added and removed)
  def tag_diff
    original = Set.new(original_tags)
    corrected = Set.new(corrected_tags)

    {
      added: corrected - original,
      removed: original - corrected,
      unchanged: original & corrected
    }
  end
end
