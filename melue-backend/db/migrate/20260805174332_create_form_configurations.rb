class CreateFormConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :form_configurations do |t|
      t.integer :form_type, null: false
      t.string :form_name, null: false
      t.integer :revision_number, default: 1, null: false
      t.date :revision_date
      t.string :organization_name
      t.jsonb :field_schema, default: {}, null: false
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end

    add_index :form_configurations, :form_type
    add_index :form_configurations, :field_schema, using: :gin
  end
end
