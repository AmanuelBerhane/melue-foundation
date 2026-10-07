# frozen_string_literal: true

class ChangeActiveStorageAttachmentsRecordIdToString < ActiveRecord::Migration[8.1]
  def up
    change_column :active_storage_attachments, :record_id, :string
  end

  def down
    execute("DELETE FROM active_storage_attachments WHERE record_id !~ '^[0-9]+$'")
    change_column :active_storage_attachments, :record_id, :bigint, using: "record_id::bigint"
  end
end
