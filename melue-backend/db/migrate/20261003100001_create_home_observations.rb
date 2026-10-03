class CreateHomeObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :home_observations, id: :uuid do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.references :guardian, type: :uuid, null: false, foreign_key: true
      t.text :content, null: false
      t.date :observed_on, null: false
      t.datetime :submitted_at, null: false

      t.timestamps
    end

    add_index :home_observations, %i[student_id observed_on]
  end
end
