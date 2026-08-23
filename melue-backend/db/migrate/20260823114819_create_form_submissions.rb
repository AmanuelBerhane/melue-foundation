class CreateFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :form_submissions, id: :uuid do |t|
      t.references :form_configuration, null: false, foreign_key: true, type: :bigint
      t.references :submittable, polymorphic: true, null: false, type: :uuid
      t.jsonb :values, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.timestamps
      t.datetime :discarded_at

      t.index [:submittable_type, :submittable_id], unique: true
      t.index :values, using: :gin
      t.index :status
      t.index :discarded_at
    end

    add_check_constraint :form_submissions, "status IN ('draft', 'submitted', 'finalized')", name: "form_submissions_status_check"
  end
end
