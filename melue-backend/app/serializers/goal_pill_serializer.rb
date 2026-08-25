# frozen_string_literal: true

# Serializes a StudentGoal as a compact goal pill for the dashboard (FR-091, FR-095).
class GoalPillSerializer < ApplicationSerializer
  private

  def serialize(student_goal)
    base = {
      id: student_goal.id,
      name: student_goal.goal.name,
      goal_type: student_goal.goal.goal_type,
      status: student_goal.status,
      progress_percent: student_goal.progress_percent&.to_f || 0.0
    }

    if student_goal.goal.goal_type == "task_analysis"
      steps = student_goal.student_goal_steps.ordered
      base[:steps] = steps.map { |s| step_payload(s) }
      base[:goal_mastered] = steps.any? && steps.all? { |s| s.status == "mastered" }
    end

    base
  end

  def step_payload(step)
    {
      id: step.id,
      step_number: step.step_number,
      name: step.name,
      independence_percent: step.independence_percent.to_f,
      status: step.status
    }
  end
end
