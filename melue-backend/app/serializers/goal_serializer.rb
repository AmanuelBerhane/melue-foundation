# frozen_string_literal: true

# Serializes a Goal for the Goal Bank (FR-071, FR-078, FR-078a, FR-078b).
class GoalSerializer < ApplicationSerializer
  def initialize(resource, usage_counts: nil)
    super(resource)
    @usage_counts = usage_counts
  end

  private

  def serialize(goal)
    usage = if @usage_counts && @usage_counts.key?(goal.id)
              @usage_counts[goal.id]
    elsif goal.respond_to?(:custom_usage_count) && !goal.custom_usage_count.nil?
              goal.custom_usage_count
    else
              goal.usage_count
    end

    data = {
      id: goal.id,
      name: goal.name,
      description: goal.description,
      goal_domain_id: goal.goal_domain_id,
      goal_domain: goal.goal_domain ? {
        id: goal.goal_domain.id,
        name: goal.goal_domain.name,
        display_order: goal.goal_domain.display_order
      } : nil,
      goal_type: goal.goal_type,
      mastery_criteria: goal.mastery_criteria || {},
      mastery_criteria_template: goal.mastery_criteria || {},
      suggested_age_range: goal.suggested_age_range,
      applicable_therapy_groups: goal.applicable_therapy_groups || [],
      is_active: goal.is_active,
      usage_count: usage.to_i,
      created_at: goal.created_at,
      updated_at: goal.updated_at
    }

    if goal.goal_type_task_analysis?
      data[:steps] = goal.task_analysis_step_templates.order(:step_number).map do |step|
        {
          id: step.id,
          step_number: step.step_number,
          name: step.name,
          description: step.description,
          mastery_criteria: step.mastery_criteria || {}
        }
      end
    end

    data
  end
end
