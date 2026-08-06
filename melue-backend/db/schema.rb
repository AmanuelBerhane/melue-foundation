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

ActiveRecord::Schema[8.1].define(version: 2026_08_05_104615) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "goal_domains", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_goal_domains_on_name", unique: true
  end

  create_table "goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "goal_domain_id", null: false
    t.string "goal_type", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_domain_id"], name: "index_goals_on_goal_domain_id"
  end

  create_table "iups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "finalized_on"
    t.string "status", default: "draft", null: false
    t.uuid "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_iups_on_student_id"
  end

  create_table "prompt_levels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.integer "display_order", null: false
    t.boolean "is_active", default: true, null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_prompt_levels_on_display_order"
    t.index ["label"], name: "index_prompt_levels_on_label", unique: true
  end

  create_table "session_block_definitions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.time "end_time", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.string "round", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
  end

  create_table "session_participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "card_position", null: false
    t.datetime "created_at", null: false
    t.uuid "current_focus_student_goal_id"
    t.uuid "student_id", null: false
    t.uuid "teacher_student_assignment_id", null: false
    t.uuid "therapy_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_focus_student_goal_id"], name: "index_session_participants_on_current_focus_student_goal_id"
    t.index ["student_id"], name: "index_session_participants_on_student_id"
    t.index ["teacher_student_assignment_id"], name: "index_session_participants_on_teacher_student_assignment_id"
    t.index ["therapy_session_id", "card_position"], name: "idx_sp_unique_card_position_per_session", unique: true
    t.index ["therapy_session_id", "student_id"], name: "idx_sp_unique_student_per_session", unique: true
    t.index ["therapy_session_id"], name: "index_session_participants_on_therapy_session_id"
  end

  create_table "staff_members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.string "role", default: "teacher", null: false
    t.string "staff_number", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role"], name: "index_staff_members_on_role"
    t.index ["staff_number"], name: "index_staff_members_on_staff_number", unique: true
    t.index ["user_id"], name: "index_staff_members_on_user_id"
  end

  create_table "student_goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "clinical_note"
    t.datetime "created_at", null: false
    t.uuid "goal_id", null: false
    t.uuid "iup_id", null: false
    t.decimal "progress_percent", precision: 5, scale: 2, default: "0.0"
    t.string "status", default: "active", null: false
    t.uuid "student_id", null: false
    t.uuid "therapy_station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_student_goals_on_goal_id"
    t.index ["iup_id", "therapy_station_id"], name: "index_student_goals_on_iup_id_and_therapy_station_id"
    t.index ["iup_id"], name: "index_student_goals_on_iup_id"
    t.index ["student_id", "status"], name: "index_student_goals_on_student_id_and_status"
    t.index ["student_id"], name: "index_student_goals_on_student_id"
    t.index ["therapy_station_id"], name: "index_student_goals_on_therapy_station_id"
  end

  create_table "students", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth", null: false
    t.string "diagnosis"
    t.string "first_name", null: false
    t.string "guardian_name"
    t.string "guardian_phone"
    t.string "last_name", null: false
    t.string "middle_name"
    t.string "program_type", null: false
    t.string "status", default: "in_assessment", null: false
    t.string "therapy_group", null: false
    t.datetime "updated_at", null: false
  end

  create_table "teacher_student_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "scheduled_date", null: false
    t.uuid "session_block_definition_id", null: false
    t.string "status", default: "scheduled", null: false
    t.uuid "student_id", null: false
    t.uuid "teacher_id", null: false
    t.uuid "therapy_room_id", null: false
    t.uuid "therapy_station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_date", "status"], name: "index_teacher_student_assignments_on_scheduled_date_and_status"
    t.index ["session_block_definition_id"], name: "idx_on_session_block_definition_id_c7f906d3e7"
    t.index ["student_id", "session_block_definition_id", "scheduled_date"], name: "idx_tsa_unique_student_block_date", unique: true
    t.index ["student_id"], name: "index_teacher_student_assignments_on_student_id"
    t.index ["teacher_id", "scheduled_date"], name: "idx_on_teacher_id_scheduled_date_d751703e3f"
    t.index ["teacher_id"], name: "index_teacher_student_assignments_on_teacher_id"
    t.index ["therapy_room_id"], name: "index_teacher_student_assignments_on_therapy_room_id"
    t.index ["therapy_station_id"], name: "index_teacher_student_assignments_on_therapy_station_id"
  end

  create_table "therapy_rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "therapy_station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["therapy_station_id"], name: "index_therapy_rooms_on_therapy_station_id"
  end

  create_table "therapy_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.uuid "session_block_definition_id", null: false
    t.datetime "started_at"
    t.string "status", default: "in_progress", null: false
    t.uuid "teacher_id", null: false
    t.uuid "therapy_room_id", null: false
    t.uuid "therapy_station_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_block_definition_id"], name: "index_therapy_sessions_on_session_block_definition_id"
    t.index ["status"], name: "index_therapy_sessions_on_status"
    t.index ["teacher_id", "status"], name: "index_therapy_sessions_on_teacher_id_and_status"
    t.index ["teacher_id"], name: "index_therapy_sessions_on_teacher_id"
    t.index ["therapy_room_id"], name: "index_therapy_sessions_on_therapy_room_id"
    t.index ["therapy_station_id"], name: "index_therapy_sessions_on_therapy_station_id"
  end

  create_table "therapy_stations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_therapy_stations_on_name", unique: true
  end

  create_table "trials", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "client_event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "logged_at", null: false
    t.string "outcome", null: false
    t.string "prompt_label_snapshot", null: false
    t.uuid "prompt_level_id", null: false
    t.uuid "session_participant_id", null: false
    t.uuid "student_goal_id", null: false
    t.uuid "student_goal_step_id"
    t.uuid "therapy_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_event_id"], name: "index_trials_on_client_event_id", unique: true
    t.index ["prompt_level_id"], name: "index_trials_on_prompt_level_id"
    t.index ["session_participant_id", "student_goal_id", "logged_at", "id"], name: "idx_trials_stream"
    t.index ["session_participant_id"], name: "index_trials_on_session_participant_id"
    t.index ["student_goal_id"], name: "index_trials_on_student_goal_id"
    t.index ["student_goal_step_id"], name: "index_trials_on_student_goal_step_id"
    t.index ["therapy_session_id"], name: "index_trials_on_therapy_session_id"
  end

  create_table "user_login_change_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
    t.string "login", null: false
  end

  create_table "user_password_reset_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "user_verification_keys", force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(status = ANY (ARRAY[1, 2]))"
    t.check_constraint "email ~ '^[^,;@ \r\n]+@[^,@; \r\n]+.[^,@; \r\n]+$'::citext", name: "valid_email"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "goals", "goal_domains"
  add_foreign_key "iups", "students"
  add_foreign_key "session_participants", "student_goals", column: "current_focus_student_goal_id"
  add_foreign_key "session_participants", "students"
  add_foreign_key "session_participants", "teacher_student_assignments"
  add_foreign_key "session_participants", "therapy_sessions"
  add_foreign_key "staff_members", "users"
  add_foreign_key "student_goals", "goals"
  add_foreign_key "student_goals", "iups"
  add_foreign_key "student_goals", "students"
  add_foreign_key "student_goals", "therapy_stations"
  add_foreign_key "teacher_student_assignments", "session_block_definitions"
  add_foreign_key "teacher_student_assignments", "staff_members", column: "teacher_id"
  add_foreign_key "teacher_student_assignments", "students"
  add_foreign_key "teacher_student_assignments", "therapy_rooms"
  add_foreign_key "teacher_student_assignments", "therapy_stations"
  add_foreign_key "therapy_rooms", "therapy_stations"
  add_foreign_key "therapy_sessions", "session_block_definitions"
  add_foreign_key "therapy_sessions", "staff_members", column: "teacher_id"
  add_foreign_key "therapy_sessions", "therapy_rooms"
  add_foreign_key "therapy_sessions", "therapy_stations"
  add_foreign_key "trials", "prompt_levels"
  add_foreign_key "trials", "session_participants"
  add_foreign_key "trials", "student_goals"
  add_foreign_key "trials", "therapy_sessions"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
