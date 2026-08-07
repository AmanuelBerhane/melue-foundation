class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.bigint :user_id
      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id
      t.jsonb :changes, default: {}
      t.jsonb :metadata, default: {}

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :user_id
    add_index :audit_logs, :resource_type
    add_index :audit_logs, :resource_id
    add_index :audit_logs, :created_at
    add_index :audit_logs, :action
    add_foreign_key :audit_logs, :users, column: :user_id
  end
end
