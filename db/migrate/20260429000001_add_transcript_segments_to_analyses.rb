class AddTranscriptSegmentsToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :transcript_segments, :text
  end
end
