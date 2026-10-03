class AddInternalFlagToInternalStudentNotes < ActiveRecord::Migration[8.1]
  def change
    # FR-135: every note in this table is Director-only. The explicit flag lets
    # any query that touches notes filter on it and keeps the intent visible
    # in the data itself, not only in controller authorization.
    add_column :internal_student_notes, :internal_flag, :boolean, default: true, null: false
    add_index :internal_student_notes, :internal_flag
  end
end
