class CreateFavoriteEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :favorite_embeddings do |t|
      t.references :favorite, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.text :embedding, null: false      # JSON 배열 문자열
      t.string :model, null: false
      t.integer :dimensions, null: false
      t.timestamps
    end
  end
end
