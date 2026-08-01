class CreateSessionBlockDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :session_block_definitions, id: :uuid do |t|
      t.string :name, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :round, null: false
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
  end
end
