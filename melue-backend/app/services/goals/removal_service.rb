# app/services/goals/removal_service.rb
module Goals
  class RemovalService < ApplicationService
    attr_reader :student_goal, :reason, :current_user

    def initialize(student_goal, reason = nil, current_user = nil)
      @student_goal = student_goal
      @reason = reason
      @current_user = current_user
    end

    def call
      return failure("Student goal not found") unless student_goal

      # Prevent removal of mastered goals without confirmation
      if student_goal.mastered? && reason.blank?
        return failure("Please provide a reason for removing a mastered goal")
      end

      # Archive the goal instead of deleting
      student_goal.status = "archived"
      student_goal.clinical_note = "#{student_goal.clinical_note}\nRemoved at #{Time.current}"

      if reason.present?
        student_goal.clinical_note += " | Reason: #{reason}"
      end

      if student_goal.save
        success({ student_goal: student_goal, message: "Goal removed successfully" })
      else
        failure(student_goal.errors.full_messages.join(", "))
      end
    end
  end
end
