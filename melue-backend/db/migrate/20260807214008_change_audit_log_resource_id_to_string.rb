class ChangeAuditLogResourceIdToString < ActiveRecord::Migration[8.1]
  def up
    remove_index :audit_logs, :resource_id
    change_column :audit_logs, :resource_id, :string
    add_index :audit_logs, :resource_id
  end

  def down
    remove_index :audit_logs, :resource_id
    change_column :audit_logs, :resource_id, :bigint
    add_index :audit_logs, :resource_id
  end
end
