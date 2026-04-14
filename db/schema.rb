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

ActiveRecord::Schema[8.1].define(version: 2026_04_14_170000) do
  create_table "episodes", force: :cascade do |t|
    t.string "audio_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration"
    t.boolean "has_valid_segments", default: true, null: false
    t.boolean "is_replay"
    t.string "ohdio_episode_id", null: false
    t.integer "page_number"
    t.integer "position"
    t.datetime "published_at"
    t.integer "show_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["show_id", "ohdio_episode_id"], name: "index_episodes_on_show_id_and_ohdio_episode_id", unique: true
    t.index ["show_id", "position"], name: "index_episodes_on_show_id_and_position"
    t.index ["show_id"], name: "index_episodes_on_show_id"
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "episode_query"
    t.boolean "exclude_replays", default: true, null: false
    t.integer "max_episodes", default: 100, null: false
    t.string "name", null: false
    t.text "segment_query"
    t.integer "show_id", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["show_id"], name: "index_feeds_on_show_id"
    t.index ["uid"], name: "index_feeds_on_uid", unique: true
  end

  create_table "media", force: :cascade do |t|
    t.string "audio_url"
    t.datetime "created_at", null: false
    t.datetime "last_attempted_at"
    t.string "media_id", null: false
    t.text "resolve_error"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.datetime "updated_at", null: false
    t.index ["media_id"], name: "index_media_on_media_id", unique: true
  end

  create_table "segments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration"
    t.integer "episode_id", null: false
    t.string "media_id"
    t.integer "position"
    t.integer "seek_time"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["episode_id", "media_id"], name: "index_segments_on_episode_id_and_media_id"
    t.index ["episode_id", "position"], name: "index_segments_on_episode_id_and_position"
    t.index ["episode_id"], name: "index_segments_on_episode_id"
  end

  create_table "shows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.datetime "last_synced_at"
    t.integer "ohdio_id", null: false
    t.string "ohdio_type"
    t.integer "page_size"
    t.text "sync_error"
    t.string "sync_status", default: "pending", null: false
    t.string "title"
    t.integer "total_episodes"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["ohdio_id"], name: "index_shows_on_ohdio_id", unique: true
  end

  add_foreign_key "episodes", "shows"
  add_foreign_key "segments", "episodes"
end
