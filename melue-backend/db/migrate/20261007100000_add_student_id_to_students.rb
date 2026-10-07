# frozen_string_literal: true

class AddStudentIdToStudents < ActiveRecord::Migration[8.1]
  def up
    add_column :students, :student_id, :string

    # Backfill existing students with sequential IDs matching MEL/XXXX/YY
    Student.reset_column_information
    Student.unscoped.order(created_at: :asc).each_with_index do |student, idx|
      year = (student.enrolled_at || student.created_at || Time.current).strftime("%y")
      seq = (idx + 1).to_s.rjust(4, "0")
      student.update_column(:student_id, "MEL/#{seq}/#{year}")
    end

    change_column_null :students, :student_id, false
    add_index :students, :student_id, unique: true
  end

  def down
    remove_index :students, :student_id if index_exists?(:students, :student_id)
    remove_column :students, :student_id
  end
end
