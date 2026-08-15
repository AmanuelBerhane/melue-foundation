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

ActiveRecord::Schema[8.1].define(version: 2026_08_14_232114) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "abc_dropdown_options", force: :cascade do |t|
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.integer "display_order", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_other", default: false, null: false
    t.string "label", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "display_order"], name: "index_abc_dropdown_options_on_category_and_display_order"
    t.index ["category", "is_active"], name: "index_abc_dropdown_options_on_category_and_is_active"
    t.index ["category", "is_other"], name: "index_abc_dropdown_options_on_category_and_is_other", unique: true, where: "(is_other = true)"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "change_data", default: {}
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "resource_id"
    t.string "resource_type", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_id"], name: "index_audit_logs_on_resource_id"
    t.index ["resource_type"], name: "index_audit_logs_on_resource_type"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "form_configurations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "field_schema", default: {}, null: false
    t.string "form_name", null: false
    t.integer "form_type", null: false
    t.boolean "is_default", default: false, null: false
    t.string "organization_name"
    t.date "revision_date"
    t.integer "revision_number", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["field_schema"], name: "index_form_configurations_on_field_schema", using: :gin
    t.index ["form_type"], name: "index_form_configurations_on_form_type"
  end

  create_table "goal_domains", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_goal_domains_on_display_order"
    t.index ["is_active"], name: "index_goal_domains_on_is_active"
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
    t.index ["is_active"], name: "index_prompt_levels_on_is_active"
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
    t.index ["is_active"], name: "index_session_block_definitions_on_is_active"
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

  create_table "session_schedule_configs", force: :cascade do |t|
    t.time "afternoon_end_time", null: false
    t.time "afternoon_start_time", null: false
    t.datetime "created_at", null: false
    t.integer "draft_expiry_days", default: 7, null: false
    t.time "morning_end_time", null: false
    t.time "morning_start_time", null: false
    t.integer "pre_therapy_duration_minutes", default: 15, null: false
    t.integer "staff_to_student_capacity", default: 4, null: false
    t.integer "station_1_duration_minutes", default: 30, null: false
    t.integer "station_2_duration_minutes", default: 30, null: false
    t.datetime "updated_at", null: false
  end

  create_table "session_summaries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "qualitative_notes"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_user_id"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.uuid "therapy_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewed_by_user_id"], name: "index_session_summaries_on_reviewed_by_user_id"
    t.index ["status", "submitted_at"], name: "index_session_summaries_on_status_and_submitted_at"
    t.index ["status"], name: "index_session_summaries_on_status"
    t.index ["submitted_at"], name: "index_session_summaries_on_submitted_at"
    t.index ["therapy_session_id"], name: "index_session_summaries_on_therapy_session_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'submitted'::character varying, 'reviewed'::character varying]::text[])", name: "session_summaries_status_check"
  end

  create_table "staff_members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.string "staff_number", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
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
    t.integer "role", default: 2, null: false
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(status = ANY (ARRAY[1, 2]))"
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "email ~ '^[^,;@ \r\n]+@[^,@; \r\n]+.[^,@; \r\n]+$'::citext", name: "valid_email"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "goals", "goal_domains"
  add_foreign_key "iups", "students"
  add_foreign_key "session_participants", "student_goals", column: "current_focus_student_goal_id"
  add_foreign_key "session_participants", "students"
  add_foreign_key "session_participants", "teacher_student_assignments"
  add_foreign_key "session_participants", "therapy_sessions"
  add_foreign_key "session_summaries", "therapy_sessions"
  add_foreign_key "session_summaries", "users", column: "reviewed_by_user_id"
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
