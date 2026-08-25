# frozen_string_literal: true

class CreateAbllsAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :ablls_assessments, id: :uuid do |t|
      t.references :assessment_cycle, type: :uuid, null: false, foreign_key: true
      t.references :staff_member,     type: :uuid, null: false, foreign_key: true
      t.string   :status,       null: false, default: "draft"
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :ablls_assessments, :assessment_cycle_id, unique: true,
              name: "index_ablls_assessments_on_assessment_cycle_id_unique"
    add_index :ablls_assessments, :status
    add_index :ablls_assessments, :discarded_at
  end
end
