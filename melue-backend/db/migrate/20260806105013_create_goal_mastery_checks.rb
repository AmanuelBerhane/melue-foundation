class CreateGoalMasteryChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_mastery_checks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :student_goal, null: false, foreign_key: true, type: :uuid
      t.uuid :initiating_teacher_id
      t.string :status
      t.uuid :approving_director_id
      t.text :rejection_reason

      t.timestamps
    end
  end
end
