class CreateSessionScheduleConfig < ActiveRecord::Migration[8.1]
  def change
    create_table :session_schedule_configs do |t|
      t.time :morning_start_time, null: false
      t.time :morning_end_time, null: false
      t.time :afternoon_start_time, null: false
      t.time :afternoon_end_time, null: false
      t.integer :pre_therapy_duration_minutes, null: false, default: 15
      t.integer :station_1_duration_minutes, null: false, default: 30
      t.integer :station_2_duration_minutes, null: false, default: 30
      t.integer :staff_to_student_capacity, null: false, default: 4
      t.integer :draft_expiry_days, null: false, default: 7

      t.timestamps
    end
  end
end
