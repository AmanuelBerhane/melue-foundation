# frozen_string_literal: true

module Goals
  # FR-078b: Imports a predefined task analysis template and creates the Task Analysis goal with steps.
  class ImportTemplateService < ApplicationService
    def initialize(file: nil, template_data: nil, user: nil, overrides: {})
      @input = file || template_data
      @user = user
      @overrides = (overrides || {}).with_indifferent_access
    end

    def call
      parse_result = TaskAnalysisTemplateParser.call(@input)
      return parse_result unless parse_result.success?

      parsed = parse_result.data

      domain = resolve_domain(parsed)
      return failure("Goal domain is required and could not be resolved") unless domain

      task_name = @overrides[:name].presence ||
                  @overrides[:task_name].presence ||
                  parsed[:name].presence

      return failure("Task name is required") if task_name.blank?

      ActiveRecord::Base.transaction do
        goal = Goal.new(
          name: task_name,
          description: @overrides[:description] || parsed[:description],
          goal_domain: domain,
          goal_type: "task_analysis",
          suggested_age_range: @overrides[:suggested_age_range] || parsed[:suggested_age_range],
          applicable_therapy_groups: @overrides[:applicable_therapy_groups] || parsed[:applicable_therapy_groups] || [],
          mastery_criteria: @overrides[:mastery_criteria] || parsed[:mastery_criteria] || {},
          is_active: true
        )

        parsed[:steps].each do |step|
          goal.task_analysis_step_templates.build(
            step_number: step[:step_number],
            name: step[:name],
            description: step[:description],
            mastery_criteria: step[:mastery_criteria] || {}
          )
        end

        if goal.save
          log_audit(goal)
          success(goal)
        else
          failure(goal.errors.full_messages.join(", "))
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    rescue => e
      failure("Failed to import task analysis template: #{e.message}")
    end

    private

    def resolve_domain(parsed)
      domain_id = @overrides[:goal_domain_id] || @overrides[:domain_id] || parsed[:goal_domain_id]
      return GoalDomain.find_by(id: domain_id) if domain_id.present?

      domain_name = @overrides[:domain_name] || parsed[:domain_name]
      if domain_name.present?
        found = GoalDomain.where("LOWER(name) = ?", domain_name.downcase).first
        return found if found
      end

      GoalDomain.active.first
    end

    def log_audit(goal)
      user_id = @user&.id || Current.user&.id
      return unless user_id

      AuditLog.create!(
        user_id: user_id,
        action: "import_task_analysis_template",
        resource_type: "Goal",
        resource_id: goal.id.to_s,
        metadata: {
          goal_name: goal.name,
          steps_count: goal.task_analysis_step_templates.size
        }
      )
    end
  end
end
