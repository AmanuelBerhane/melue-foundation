class CreateTaskAnalysisSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :task_analysis_step_templates, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.integer :step_number, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :mastery_criteria, default: {}, null: false
      t.timestamps
    end

    add_index :task_analysis_step_templates, %i[goal_id step_number], unique: true,
              name: "idx_task_analysis_step_templates_on_goal_and_number"

    create_table :student_goal_steps, id: :uuid do |t|
      t.references :student_goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :task_analysis_step_template, type: :uuid, null: true,
                   foreign_key: { on_delete: :nullify }
      t.integer :step_number, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :independence_percent, precision: 5, scale: 2, default: 0.0, null: false
      t.string :status, default: "not_started", null: false
      t.timestamps
    end

    add_index :student_goal_steps, %i[student_goal_id step_number], unique: true,
              name: "idx_student_goal_steps_on_student_goal_and_number"
    add_index :student_goal_steps, %i[student_goal_id status],
              name: "idx_student_goal_steps_on_student_goal_and_status"

    # Performance index for progress calculation (critical for < 500 ms NFR)
    add_index :trials, %i[student_goal_step_id outcome prompt_level_id],
              name: "idx_trials_step_outcome"

    # Non-blocking FK (zero-downtime)
    add_foreign_key :trials, :student_goal_steps,
                    column: :student_goal_step_id,
                    validate: false
  end
end
