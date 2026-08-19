class CreateSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :session_summaries, id: :uuid do |t|
      t.references :therapy_session, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.text :qualitative_notes
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.references :reviewed_by_user, foreign_key: { to_table: :users }, type: :bigint, null: true
      t.datetime :reviewed_at

      t.timestamps
    end
  end
end
