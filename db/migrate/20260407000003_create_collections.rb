class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description

      t.timestamps
    end
  end
end
