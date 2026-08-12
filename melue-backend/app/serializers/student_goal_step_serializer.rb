# frozen_string_literal: true

# Serializes a StudentGoalStep with trial progress indicators (FR-095).
class StudentGoalStepSerializer < ApplicationSerializer
  private

  def serialize(step)
    {
      id: step.id,
      step_number: step.step_number,
      name: step.name,
      description: step.description,
      independence_percent: step.independence_percent.to_f,
      status: step.status
    }
  end
end
