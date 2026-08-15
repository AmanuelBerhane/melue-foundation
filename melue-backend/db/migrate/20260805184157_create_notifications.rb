# db/migrate/20260805000001_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.bigint  :recipient_user_id, null: false
      t.string  :type, null: false        # careful: see note below on STI
      t.text    :payload_reference, null: false
      t.timestamp :read_at
      t.timestamp :created_at, null: false
    end

    add_index :notifications, :recipient_user_id
    add_index :notifications, :read_at
    add_foreign_key :notifications, :users, column: :recipient_user_id
  end
end
