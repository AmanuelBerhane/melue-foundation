# frozen_string_literal: true

module Iups
  class ReplaceGoalService < ApplicationService
    def initialize(student_goal:, new_goal:, current_user: nil)
      @student_goal = student_goal
      @new_goal = new_goal
      @iup = student_goal.iup
      @therapy_station = student_goal.therapy_station
      @current_user = current_user
    end

    def call
      validate_replacement_goal

      ActiveRecord::Base.transaction do
        capture_old_goal_name
        remove_existing_steps
        update_goal_assignment
        create_new_steps if @new_goal.goal_type_task_analysis?
        log_replacement
      end

      success(student_goal: @student_goal.reload)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_replacement_goal
      unless @new_goal.is_active?
        raise ValidationError, "Replacement goal is not active"
      end

      unless @new_goal.applicable_to_therapy_group?(@iup.student.therapy_group)
        raise ValidationError, "Replacement goal not applicable to student's therapy group"
      end
    end

    def capture_old_goal_name
      @old_goal_name = @student_goal.goal.name
    end

    def remove_existing_steps
      @student_goal.student_goal_steps.destroy_all
    end

    def update_goal_assignment
      @student_goal.update!(
        goal: @new_goal,
        progress_percent: 0.0
      )
    end

    def create_new_steps
      templates = @new_goal.task_analysis_step_templates.order(:step_number)

      templates.each do |template|
        StudentGoalStep.create!(
          student_goal: @student_goal,
          task_analysis_step_template: template,
          step_number: template.step_number,
          name: template.name,
          description: template.description,
          status: "not_started",
          independence_percent: 0.0
        )
      end
    end

    def log_replacement
      user_id = @current_user&.id || Current.user&.id
      return unless user_id

      AuditLog.create!(
        resource_type: "StudentGoal",
        resource_id: @student_goal.id.to_s,
        action: "goal_replaced",
        user_id: user_id,
        change_data: {
          old_goal_name: @old_goal_name,
          new_goal_id: @new_goal.id,
          new_goal_name: @new_goal.name,
          iup_id: @iup.id
        }
      )
    end

    class ValidationError < StandardError; end
  end
end
