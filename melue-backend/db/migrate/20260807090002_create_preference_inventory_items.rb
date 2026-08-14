class CreatePreferenceInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :preference_inventory_items, id: :uuid do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps

      # One entry per name within a category; the catalogue is administered
      # centrally and must not accumulate duplicates.
      t.index [ :category, :name ], unique: true
      t.index :is_active
    end
  end
end
