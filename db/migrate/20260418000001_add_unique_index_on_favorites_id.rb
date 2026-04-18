class AddUniqueIndexOnFavoritesId < ActiveRecord::Migration[8.1]
  def change
    add_index :favorites, :id, unique: true, if_not_exists: true
  end
end
