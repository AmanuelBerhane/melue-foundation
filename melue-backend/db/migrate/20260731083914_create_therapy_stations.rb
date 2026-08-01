class CreateTherapyStations < ActiveRecord::Migration[8.1]
  def change
    create_table :therapy_stations, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps

      t.index :name, unique: true
    end
  end
end
