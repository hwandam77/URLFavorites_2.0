class AddAnalysisStyleToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :analysis_style, :string, default: "execution_brief", null: false
  end
end
