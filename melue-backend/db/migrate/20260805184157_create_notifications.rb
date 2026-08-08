class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.uuid :recipient_user_id
      t.string :type
      t.text :payload_reference
      t.timestamp :read_at

      t.timestamps
    end
  end
end
