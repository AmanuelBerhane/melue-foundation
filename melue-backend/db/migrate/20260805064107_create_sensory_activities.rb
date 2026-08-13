class CreateSensoryActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :sensory_activities, id: :uuid do |t|
      t.string :activity_code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, null: false, default: true
      t.integer :display_order, null: false, default: 0

      t.timestamps
    end
    add_index :sensory_activities, :activity_code, unique: true
  end
end
