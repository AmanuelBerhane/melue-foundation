class CreateSessionParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :session_participants, id: :uuid do |t|
      t.references :therapy_session, null: false, foreign_key: true, type: :uuid
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :teacher_student_assignment, null: false, foreign_key: true, type: :uuid
      t.references :current_focus_student_goal, foreign_key: { to_table: :student_goals },
                   type: :uuid, null: true
      t.integer :card_position, null: false
      t.timestamps

      # Each card slot (active/secondary) must be unique per session
      t.index [ :therapy_session_id, :card_position ],
               name: "idx_sp_unique_card_position_per_session", unique: true

      # A student can only appear once per session
      t.index [ :therapy_session_id, :student_id ],
               name: "idx_sp_unique_student_per_session", unique: true
    end
  end
end
