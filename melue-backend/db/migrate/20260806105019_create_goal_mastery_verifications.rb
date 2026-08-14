class CreateGoalMasteryVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_mastery_verifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :goal_mastery_check, null: false, foreign_key: true, type: :uuid
      t.uuid :verifying_teacher_id
      t.string :outcome
      t.string :prompt_used
      t.text :notes

      t.timestamps
    end
  end
end
