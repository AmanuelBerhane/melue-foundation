class AddCreatedAtToNotification < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :created_at, :timestamp
  end
end
