# frozen_string_literal: true

# Serializes a StudentGoal as a compact goal pill for the dashboard (FR-091).
class GoalPillSerializer < ApplicationSerializer
  private

  def serialize(student_goal)
    {
      id: student_goal.id,
      name: student_goal.goal.name,
      goal_type: student_goal.goal.goal_type,
      status: student_goal.status,
      progress_percent: student_goal.progress_percent
    }
  end
end
