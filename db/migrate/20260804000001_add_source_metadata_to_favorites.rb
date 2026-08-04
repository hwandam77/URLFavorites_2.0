class AddSourceMetadataToFavorites < ActiveRecord::Migration[8.1]
  def change
    add_column :favorites, :source_metadata, :text
  end
end
