class CreateAnalysisSections < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_sections do |t|
      t.references :analysis, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :heading, null: false
      t.text :focus
      t.text :body
      t.string :backend_model
      t.timestamps
    end
    add_index :analysis_sections, [ :analysis_id, :position ], unique: true
  end
end
