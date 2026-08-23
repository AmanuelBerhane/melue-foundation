# frozen_string_literal: true

module Iups
  class AssignGoalService < ApplicationService
    def initialize(iup:, goal:, therapy_station:)
      @iup = iup
      @goal = goal
      @therapy_station = therapy_station
      @student = iup.student
    end

    def call
      validate_goal_eligibility
      validate_station_capacity
      
      ActiveRecord::Base.transaction do
        assign_goal
        create_task_analysis_steps if @goal.goal_type_task_analysis?
        log_assignment
      end
      
      success(student_goal: @student_goal)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_goal_eligibility
      unless @goal.is_active?
        raise ValidationError, "Goal is not active"
      end

      unless @goal.applicable_to_therapy_group?(@student.therapy_group)
        raise ValidationError, "Goal '#{@goal.name}' is not applicable to #{@student.therapy_group} therapy group"
      end
    end

    def validate_station_capacity
      existing_count = StudentGoal.kept.where(
        iup: @iup,
        therapy_station: @therapy_station,
        status: "active"
      ).count

      if existing_count >= 2
        raise ValidationError, "Maximum 2 active goals per station - remove or replace existing goals first"
      end
    end

    def assign_goal
      @student_goal = StudentGoal.create!(
        iup: @iup,
        student: @student,
        goal: @goal,
        therapy_station: @therapy_station,
        status: "active",
        progress_percent: 0.0
      )
    end

    def create_task_analysis_steps
      templates = @goal.task_analysis_step_templates.order(:step_number)
      
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

    def log_assignment
      AuditLog.create!(
        resource_type: "StudentGoal",
        resource_id: @student_goal.id.to_s,
        action: "goal_assigned",
        user_id: Current.user&.id,
        change_data: {
          goal_id: @goal.id,
          goal_name: @goal.name,
          station_id: @therapy_station.id,
          iup_id: @iup.id
        }
      )
    end

    class ValidationError < StandardError; end
  end
end
