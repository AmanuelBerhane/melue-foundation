class AddGoalTherapyGroupFields < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :suggested_age_range, :string
    add_column :goals, :applicable_therapy_groups, :string, array: true, default: []
    add_column :goals, :mastery_criteria, :jsonb, default: {}

    add_index :goals, :applicable_therapy_groups, using: :gin
  end
end
