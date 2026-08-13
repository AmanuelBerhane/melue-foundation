class CreateRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.datetime :assigned_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :revoked_at

      t.timestamps

      t.index [ :user_id, :role_id, :revoked_at ], name: "idx_role_assignments_user_role_revoked"
    end
  end
end
