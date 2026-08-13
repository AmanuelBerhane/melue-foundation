class AddGuardianFieldsToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :guardian_name, :string
    add_column :students, :guardian_phone, :string
  end
end
