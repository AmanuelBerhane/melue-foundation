class CreateStudentGuardians < ActiveRecord::Migration[8.1]
  def change
    create_table :student_guardians, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.references :guardian, null: false, foreign_key: true, type: :uuid
      t.string :relationship, null: false
      t.boolean :is_primary_contact, null: false, default: false
      t.timestamps

      t.index [ :student_id, :guardian_id ], unique: true, name: "idx_student_guardians_unique_pair"
    end
  end
end
