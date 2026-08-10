class CreateGuardians < ActiveRecord::Migration[8.1]
  def change
    create_table :guardians, id: :uuid do |t|
      t.references :user, foreign_key: true, type: :bigint
      t.string :full_name, null: false
      t.string :phone
      t.timestamps
    end
  end
end
