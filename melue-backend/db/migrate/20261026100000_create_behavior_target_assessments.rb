# frozen_string_literal: true

class CreateBehaviorTargetAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :behavior_target_assessments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :behavior_assessment, type: :uuid, null: false, foreign_key: true, index: true
      t.string :behavior_name, null: false
      t.jsonb :mass_responses, default: {}
      t.jsonb :fast_responses, default: {}
      t.jsonb :function_scores, default: {}
      t.jsonb :risk_indicators, default: {}
      t.string :dominant_function
      t.string :hypothesized_function
      t.string :status, default: "draft", null: false
      t.datetime :completed_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :behavior_target_assessments, :status
    add_index :behavior_target_assessments, :discarded_at
  end
end
