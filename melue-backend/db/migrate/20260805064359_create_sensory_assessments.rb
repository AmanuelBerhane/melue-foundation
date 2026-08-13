class CreateSensoryAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :sensory_assessments, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: 'draft'

      t.timestamps
    end
    add_index :sensory_assessments, :status
  end
end
