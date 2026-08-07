class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :prompt_levels, :is_active
    add_index :goal_domains, :is_active
    add_index :goal_domains, :display_order
    add_index :session_block_definitions, :is_active
  end
end
