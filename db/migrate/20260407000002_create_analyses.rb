class CreateAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :analyses do |t|
      t.references :favorite, null: false, foreign_key: true, index: { unique: true }
      t.text :summary
      t.text :tags
      t.text :key_points
      t.string :sentiment
      t.text :transcript
      t.string :subtitle_source
      t.text :video_metadata
      t.string :model_used
      t.datetime :analyzed_at

      t.timestamps
    end
  end
end
