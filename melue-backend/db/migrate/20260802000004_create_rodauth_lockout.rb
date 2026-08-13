class CreateRodauthLockout < ActiveRecord::Migration[8.1]
  def change
    # Used by the account lockout feature (NFR-019: 5 failed logins -> 15 min lockout)
    create_table :user_login_failures, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :users, column: :id
      t.integer :number, null: false, default: 1
    end

    create_table :user_lockouts, id: false do |t|
      t.bigint :id, primary_key: true
      t.foreign_key :users, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent, default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
