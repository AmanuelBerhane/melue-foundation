class CreateGoalDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_domains, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.integer :display_order, null: false, default: 0
      t.boolean :is_active, null: false, default: true
      t.timestamps

      t.index :name, unique: true
    end
  end
end
