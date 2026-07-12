# frozen_string_literal: true

class AddEmbeddingToFavoritesFts < ActiveRecord::Migration[8.0]
  def up
    # FTS5 virtual table cannot be altered, so recreate with new column
    execute "DROP TABLE IF EXISTS favorites_fts"

    execute <<~SQL
      CREATE VIRTUAL TABLE favorites_fts USING fts5(
        favorite_id UNINDEXED,
        title,
        summary,
        tags,
        note,
        content_embedding,
        tokenize='porter ascii'
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS favorites_fts"

    execute <<~SQL
      CREATE VIRTUAL TABLE favorites_fts USING fts5(
        favorite_id UNINDEXED,
        title,
        summary,
        tags,
        note,
        tokenize='porter ascii'
      )
    SQL
  end
end
