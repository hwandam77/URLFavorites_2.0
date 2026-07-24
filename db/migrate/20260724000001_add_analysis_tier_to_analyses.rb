class AddAnalysisTierToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :analysis_tier, :string, default: "fast", null: false
  end
end
