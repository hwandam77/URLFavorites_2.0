class AddCategoryAndPinnedToFavorites < ActiveRecord::Migration[8.1]
  def change
    add_column :favorites, :category, :string, default: "기타"
    add_column :favorites, :pinned, :boolean, default: false
    add_index :favorites, :category
    add_index :favorites, :pinned
  end
end
