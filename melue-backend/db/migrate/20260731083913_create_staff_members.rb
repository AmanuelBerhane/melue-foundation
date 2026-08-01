class CreateStaffMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_members, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.string :full_name, null: false
      t.string :staff_number, null: false
      t.timestamps

      t.index :staff_number, unique: true
    end
  end
end
