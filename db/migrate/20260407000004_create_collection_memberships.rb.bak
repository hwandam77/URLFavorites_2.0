class CreateCollectionMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_memberships do |t|
      t.references :favorite, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true

      t.timestamps
    end

    add_index :collection_memberships, [:favorite_id, :collection_id], unique: true
  end
end
