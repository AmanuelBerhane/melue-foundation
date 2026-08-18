class CreateFastAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :fast_assessments, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :assessment_cycle, foreign_key: true, type: :uuid
      t.references :teacher, foreign_key: { to_table: :staff_members }, type: :uuid
      t.jsonb :responses, default: {}
      t.jsonb :risk_indicators, default: {}
      t.string :status, default: "draft"
      t.datetime :completed_at
      t.timestamps
    end
    add_index :fast_assessments, [ :student_id, :status ]
  end
end
