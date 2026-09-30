# frozen_string_literal: true

class CreateStaffAvailabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :staff_availabilities, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :staff_member, null: false, foreign_key: true, type: :uuid, index: true
      t.references :session_block_definition, null: true, foreign_key: true, type: :uuid, index: true
      t.date :unavailable_date, null: false
      t.text :reason

      t.timestamps
    end

    add_index :staff_availabilities, [ :unavailable_date ]

    add_index :staff_availabilities,
              [ :staff_member_id, :unavailable_date ],
              unique: true,
              where: "session_block_definition_id IS NULL",
              name: "idx_staff_availabilities_full_day_unique"

    add_index :staff_availabilities,
              [ :staff_member_id, :unavailable_date, :session_block_definition_id ],
              unique: true,
              where: "session_block_definition_id IS NOT NULL",
              name: "idx_staff_availabilities_block_unique"
  end
end
