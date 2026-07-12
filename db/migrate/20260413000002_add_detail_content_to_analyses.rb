class AddDetailContentToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :detail_content, :text
  end
end
