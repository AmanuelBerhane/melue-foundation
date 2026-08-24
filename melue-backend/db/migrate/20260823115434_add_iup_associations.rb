class AddIupAssociations < ActiveRecord::Migration[8.1]
  def change
    add_column :iups, :assessment_cycle_id, :uuid
    add_column :iups, :created_by_user_id, :bigint
    add_column :iups, :finalized_by_user_id, :bigint

    add_foreign_key :iups, :assessment_cycles
    add_foreign_key :iups, :users, column: :created_by_user_id
    add_foreign_key :iups, :users, column: :finalized_by_user_id

    add_index :iups, :assessment_cycle_id
    add_index :iups, :created_by_user_id
    add_index :iups, :finalized_by_user_id
    add_index :iups, :finalized_on
    add_index :iups, [ :student_id, :status ], where: "status = 'active'", name: "index_iups_on_student_active"
    add_index :iups, [ :student_id, :status ], where: "status = 'draft'", name: "index_iups_on_student_draft", unique: true
  end
end
