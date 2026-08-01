class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals, id: :uuid do |t|
      t.references :goal_domain, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :goal_type, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
  end
end
