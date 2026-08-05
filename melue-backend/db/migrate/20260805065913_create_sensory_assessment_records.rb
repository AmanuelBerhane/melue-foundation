class CreateSensoryAssessmentRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :sensory_assessment_records, id: :uuid do |t|
      t.references :sensory_assessment, null: false, foreign_key: true, type: :uuid
      t.references :sensory_activity, null: false, foreign_key: true, type: :uuid
      t.string :engagement_level
      t.string :response_reaction
      t.text :remark

      t.timestamps
    end
  end
end
