class AddRawContentToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :raw_content, :text
  end
end
