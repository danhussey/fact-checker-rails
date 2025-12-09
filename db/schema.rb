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

ActiveRecord::Schema[8.0].define(version: 2025_12_09_132506) do
  create_table "fact_checks", force: :cascade do |t|
    t.integer "listening_session_id", null: false
    t.string "claim", null: false
    t.integer "triggered_by_chunk_id"
    t.string "verdict"
    t.integer "confidence"
    t.json "whats_true"
    t.json "whats_wrong"
    t.json "context_points"
    t.json "sources"
    t.string "status", default: "pending"
    t.datetime "processing_started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listening_session_id", "created_at"], name: "index_fact_checks_on_listening_session_id_and_created_at"
    t.index ["listening_session_id"], name: "index_fact_checks_on_listening_session_id"
    t.index ["status"], name: "index_fact_checks_on_status"
  end

  create_table "listening_sessions", force: :cascade do |t|
    t.string "session_token", null: false
    t.string "status", default: "idle"
    t.boolean "recording_enabled", default: false
    t.string "deepgram_connection_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_enabled"], name: "index_listening_sessions_on_recording_enabled"
    t.index ["session_token"], name: "index_listening_sessions_on_session_token", unique: true
  end

  create_table "transcript_chunks", force: :cascade do |t|
    t.integer "listening_session_id", null: false
    t.text "text", null: false
    t.boolean "is_final", default: false
    t.float "confidence"
    t.float "start_time"
    t.float "end_time"
    t.json "words"
    t.integer "speaker"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listening_session_id", "start_time"], name: "index_transcript_chunks_on_listening_session_id_and_start_time"
    t.index ["listening_session_id"], name: "index_transcript_chunks_on_listening_session_id"
  end

  add_foreign_key "fact_checks", "listening_sessions"
  add_foreign_key "transcript_chunks", "listening_sessions"
end
