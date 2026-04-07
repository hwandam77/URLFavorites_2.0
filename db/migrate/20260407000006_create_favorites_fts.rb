class CreateFavoritesFts < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS favorites_fts USING fts5(
        favorite_id UNINDEXED,
        title,
        summary,
        tags,
        note,
        tokenize='porter ascii'
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS favorites_fts"
  end
end
