class CreateRodauthJwtRefresh < ActiveRecord::Migration[8.1]
  def change
    # Used by the jwt refresh feature
    create_table :user_jwt_refresh_keys do |t|
      t.references :user, foreign_key: true, null: false
      t.string :key, null: false
      t.datetime :deadline, null: false
    end
  end
end
