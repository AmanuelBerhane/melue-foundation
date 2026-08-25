class AddDiscardedAtToSyncableModels < ActiveRecord::Migration[8.1]
  def change
    tables = %i[
      assessment_cycles
      goal_domains
      goals
      iups
      preference_assessments
      preference_inventory_items
      preference_observations
      prompt_levels
      session_block_definitions
      session_participants
      staff_members
      student_goals
      students
      teacher_student_assignments
      therapy_rooms
      therapy_sessions
      therapy_stations
      trials
    ]

    tables.each do |table_name|
      add_column table_name, :discarded_at, :datetime
      add_index table_name, :discarded_at
    end
  end
end
