class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students, id: :uuid do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :middle_name
      t.date :date_of_birth, null: false
      t.string :diagnosis
      t.string :program_type, null: false
      t.string :therapy_group, null: false
      t.string :status, null: false, default: "in_assessment"
      t.timestamps
    end
  end
end
