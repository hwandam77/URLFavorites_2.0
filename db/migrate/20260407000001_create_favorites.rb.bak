class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.string :url, null: false, index: { unique: true }
      t.string :title
      t.string :favicon_url
      t.string :thumbnail_url
      t.string :content_type, null: false, default: "webpage"
      t.string :status, null: false, default: "pending"
      t.text :raw_content
      t.text :error_message
      t.integer :retry_count, null: false, default: 0
      t.text :note

      t.timestamps
    end
  end
end
