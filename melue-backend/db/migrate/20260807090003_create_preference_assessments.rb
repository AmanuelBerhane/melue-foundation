class CreatePreferenceAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :preference_assessments, id: :uuid do |t|
      # A cycle requires exactly one preference assessment (0..1 until started),
      # so the FK carries a unique index rather than a plain one.
      t.references :assessment_cycle, null: false, foreign_key: true, type: :uuid,
                   index: { unique: true }
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
