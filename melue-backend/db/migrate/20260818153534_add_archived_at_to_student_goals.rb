class AddArchivedAtToStudentGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :student_goals, :archived_at, :datetime
  end
end
