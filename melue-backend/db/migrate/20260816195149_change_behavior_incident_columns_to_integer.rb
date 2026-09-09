class ChangeBehaviorIncidentColumnsToInteger < ActiveRecord::Migration[8.0]
  def up
    # Remove the string columns and add integer columns
    remove_column :behavior_incidents, :frequency, :string
    remove_column :behavior_incidents, :intensity, :string
    remove_column :behavior_incidents, :category, :string

    add_column :behavior_incidents, :frequency, :integer, default: 0, null: false
    add_column :behavior_incidents, :intensity, :integer, default: 0, null: false
    add_column :behavior_incidents, :category, :integer, default: 0, null: false
  end

  def down
    # Reverse: remove integer columns, add back string columns
    remove_column :behavior_incidents, :frequency, :integer
    remove_column :behavior_incidents, :intensity, :integer
    remove_column :behavior_incidents, :category, :integer

    add_column :behavior_incidents, :frequency, :string
    add_column :behavior_incidents, :intensity, :string
    add_column :behavior_incidents, :category, :string
  end
end
