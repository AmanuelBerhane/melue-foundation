class CreateTrials < ActiveRecord::Migration[8.1]
  def change
    create_table :trials, id: :uuid do |t|
      t.references :therapy_session, null: false, foreign_key: true, type: :uuid
      t.references :session_participant, null: false, foreign_key: true, type: :uuid
      t.references :student_goal, null: false, foreign_key: true, type: :uuid
      t.references :student_goal_step, foreign_key: false, type: :uuid, null: true
      t.references :prompt_level, null: false, foreign_key: true, type: :uuid
      t.string :prompt_label_snapshot, null: false
      t.string :outcome, null: false
      t.datetime :logged_at, null: false

      # Client-assigned UUID for idempotent offline sync — globally unique
      t.string :client_event_id, null: false

      t.timestamps

      t.index :client_event_id, unique: true

      # Index for fast last-N trial stream queries per participant/goal
      t.index [ :session_participant_id, :student_goal_id, :logged_at, :id ],
               name: "idx_trials_stream"
    end
  end
end
