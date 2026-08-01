class CreateTeacherStudentAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :teacher_student_assignments, id: :uuid do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :staff_members }, type: :uuid
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :session_block_definition, null: false, foreign_key: true, type: :uuid
      t.references :therapy_station, null: false, foreign_key: true, type: :uuid
      t.references :therapy_room, null: false, foreign_key: true, type: :uuid
      t.date :scheduled_date, null: false
      t.string :status, null: false, default: "scheduled"
      t.timestamps

      # A student cannot be assigned to more than one teacher per block/date
      t.index [ :student_id, :session_block_definition_id, :scheduled_date ],
               name: "idx_tsa_unique_student_block_date", unique: true

      t.index [ :teacher_id, :scheduled_date ]
      t.index [ :scheduled_date, :status ]
    end
  end
end
