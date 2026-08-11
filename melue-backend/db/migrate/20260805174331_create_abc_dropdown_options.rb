class CreateAbcDropdownOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :abc_dropdown_options do |t|
      t.integer :category, null: false
      t.string :label, null: false
      t.integer :display_order, null: false
      t.boolean :is_active, default: true, null: false
      t.boolean :is_other, default: false, null: false

      t.timestamps
    end

    add_index :abc_dropdown_options, [ :category, :display_order ]
    add_index :abc_dropdown_options, [ :category, :is_active ]
    add_index :abc_dropdown_options, [ :category, :is_other ], unique: true, where: "is_other = true"
  end
end
