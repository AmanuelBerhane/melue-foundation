class CreateBehaviorIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :behavior_incidents, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :staff_member, foreign_key: true, type: :uuid
      t.references :therapy_session, foreign_key: true, type: :uuid
      t.references :student_goal, foreign_key: true, type: :uuid

      t.string :behavior_name, null: false
      t.text :behavior_definition, null: false
      t.string :frequency, null: false
      t.string :intensity, null: false
      t.string :category, null: false

      t.text :antecedent, null: false
      t.text :consequence, null: false
      t.string :location, null: false

      t.datetime :occurred_at, null: false
      t.text :additional_notes

      t.timestamps
    end

    add_index :behavior_incidents, [ :student_id, :occurred_at ]
    add_index :behavior_incidents, :category
  end
end
