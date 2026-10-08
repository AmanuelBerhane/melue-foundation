class CreateParentCommunications < ActiveRecord::Migration[8.1]
  def change
    create_table :parent_communications, id: :uuid do |t|
      t.references :student, type: :uuid, null: false, foreign_key: true
      t.references :guardian, type: :uuid, null: false, foreign_key: true
      t.references :sender_user, null: false, foreign_key: { to_table: :users }
      t.string :direction, null: false
      t.string :kind, null: false, default: "general"
      t.text :content, null: false
      t.datetime :sent_at, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :parent_communications, %i[student_id sent_at]
    add_index :parent_communications, %i[guardian_id direction read_at]
    add_check_constraint :parent_communications,
                         "direction IN ('inbound', 'outbound')",
                         name: "parent_communications_direction_check"
    add_check_constraint :parent_communications,
                         "kind IN ('progress_update', 'general', 'alert')",
                         name: "parent_communications_kind_check"
  end
end
