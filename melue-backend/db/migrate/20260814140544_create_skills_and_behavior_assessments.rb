# frozen_string_literal: true

class CreateSkillsAndBehaviorAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :skills_assessments, id: :uuid do |t|
      t.references :assessment_cycle, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string     :status, null: false, default: "draft"
      t.integer    :progress_percent, null: false, default: 0
      t.datetime   :started_at
      t.datetime   :submitted_at
      t.datetime   :discarded_at
      t.timestamps
    end
    add_index :skills_assessments, :status
    add_index :skills_assessments, :discarded_at

    create_table :behavior_assessments, id: :uuid do |t|
      t.references :assessment_cycle, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string     :status, null: false, default: "draft"
      t.datetime   :started_at
      t.datetime   :submitted_at
      t.datetime   :discarded_at
      t.timestamps
    end
    add_index :behavior_assessments, :status
    add_index :behavior_assessments, :discarded_at
  end
end
