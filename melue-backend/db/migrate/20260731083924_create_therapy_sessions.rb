class CreateTherapySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :therapy_sessions, id: :uuid do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :staff_members }, type: :uuid
      t.references :session_block_definition, null: false, foreign_key: true, type: :uuid
      t.references :therapy_station, null: false, foreign_key: true, type: :uuid
      t.references :therapy_room, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "in_progress"
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps

      t.index :status
      t.index [ :teacher_id, :status ]
    end
  end
end
