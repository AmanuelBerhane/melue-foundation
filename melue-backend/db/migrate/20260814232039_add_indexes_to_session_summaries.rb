class AddIndexesToSessionSummaries < ActiveRecord::Migration[8.1]
  def change
    add_index :session_summaries, :status
    add_index :session_summaries, :submitted_at
    add_index :session_summaries, [ :status, :submitted_at ],
              name: 'index_session_summaries_on_status_and_submitted_at'
  end
end
