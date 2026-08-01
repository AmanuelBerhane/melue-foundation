class CreateStudentGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :student_goals, id: :uuid do |t|
      t.references :iup, null: false, foreign_key: true, type: :uuid
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :goal, null: false, foreign_key: true, type: :uuid
      t.references :therapy_station, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "active"
      t.decimal :progress_percent, precision: 5, scale: 2, default: "0.0"
      t.text :clinical_note
      t.timestamps

      t.index [ :iup_id, :therapy_station_id ]
      t.index [ :student_id, :status ]
    end
  end
end
