class AddGuardianFieldsToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :guardian_name, :string, null: false, default: ''
    add_column :students, :guardian_phone, :string, null: false, default: ''
  end
end
