class CreateAssessmentCycles < ActiveRecord::Migration[8.1]
  def change
    create_table :assessment_cycles, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "in_progress"
      t.date :started_on, null: false
      t.date :completed_on

      t.timestamps

      t.index [ :student_id, :status ]
    end
  end
end
