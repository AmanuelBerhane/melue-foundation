class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.boolean :is_system_critical, null: false, default: false
      t.boolean :is_active, null: false, default: true
      t.timestamps

      t.index :name, unique: true
    end
  end
end
