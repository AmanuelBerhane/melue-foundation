class CreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_roles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.references :role, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
