class CreateTherapyRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :therapy_rooms, id: :uuid do |t|
      t.references :therapy_station, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.timestamps
    end
  end
end
