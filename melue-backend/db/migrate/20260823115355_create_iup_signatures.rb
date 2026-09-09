class CreateIupSignatures < ActiveRecord::Migration[8.1]
  def change
    create_table :iup_signatures, id: :uuid do |t|
      t.references :iup, null: false, foreign_key: true, type: :uuid
      t.references :signer_user, null: false, foreign_key: { to_table: :users }, type: :bigint
      t.string :signer_role, null: false
      t.datetime :signed_at, null: false
      t.text :signature_evidence
      t.timestamps

      t.index [ :iup_id, :signer_role ], unique: true
      t.index :signed_at
    end

    add_check_constraint :iup_signatures, "signer_role IN ('program_director', 'guardian')", name: "iup_signatures_signer_role_check"
  end
end
