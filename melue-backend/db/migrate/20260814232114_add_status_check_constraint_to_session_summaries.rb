class AddStatusCheckConstraintToSessionSummaries < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      ALTER TABLE session_summaries
      ADD CONSTRAINT session_summaries_status_check
      CHECK (status IN ('draft', 'submitted', 'reviewed'))
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE session_summaries
      DROP CONSTRAINT session_summaries_status_check
    SQL
  end
end
