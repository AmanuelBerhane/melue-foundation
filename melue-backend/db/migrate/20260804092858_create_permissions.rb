class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions, id: :uuid do |t|
      t.string :resource, null: false
      t.string :action, null: false
      t.text :description

      t.timestamps
    end
  end
end
