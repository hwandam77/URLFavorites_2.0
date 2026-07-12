class CreateTagFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_feedbacks do |t|
      t.references :favorite, null: false, foreign_key: true
      t.references :user, null: true # nil for anonymous corrections
      t.text :original_tags, null: false  # JSON array
      t.text :corrected_tags, null: false # JSON array
      t.string :reason, limit: 500         # optional reason
      t.timestamps
    end
  end
end
