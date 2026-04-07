# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_07_000004) do
  create_table "analyses", force: :cascade do |t|
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.integer "favorite_id", null: false
    t.text "key_points"
    t.string "model_used"
    t.string "sentiment"
    t.string "subtitle_source"
    t.text "summary"
    t.text "tags"
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.text "video_metadata"
    t.index ["favorite_id"], name: "index_analyses_on_favorite_id", unique: true
  end

  create_table "collection_memberships", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.datetime "created_at", null: false
    t.integer "favorite_id", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_id"], name: "index_collection_memberships_on_collection_id"
    t.index ["favorite_id", "collection_id"], name: "index_collection_memberships_on_favorite_id_and_collection_id", unique: true
    t.index ["favorite_id"], name: "index_collection_memberships_on_favorite_id"
  end

  create_table "collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_collections_on_name", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.string "content_type", default: "webpage", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "favicon_url"
    t.text "note"
    t.text "raw_content"
    t.integer "retry_count", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["url"], name: "index_favorites_on_url", unique: true
  end

  add_foreign_key "analyses", "favorites"
  add_foreign_key "collection_memberships", "collections"
  add_foreign_key "collection_memberships", "favorites"
end
