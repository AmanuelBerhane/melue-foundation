class CreatePromptLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_levels, id: :uuid do |t|
      t.string :label, null: false
      t.string :color, null: false
      t.integer :display_order, null: false
      t.boolean :is_active, null: false, default: true
      t.timestamps

      t.index :label, unique: true
      t.index :display_order
    end
  end
end
