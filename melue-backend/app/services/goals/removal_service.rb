# app/services/goals/removal_service.rb
module Goals
  class RemovalService < ApplicationService
    attr_reader :student_goal, :reason, :current_user

    def initialize(student_goal, reason: nil, current_user: nil)
      @student_goal = student_goal
      @reason = reason
      @current_user = current_user
    end

    def call
      # Check if goal is already archived
      if student_goal.status == "archived"
        return failure("Goal is already archived")
      end

      # Check if goal is mastered
      if student_goal.status == "mastered" && reason.blank?
        return failure("Cannot remove a mastered goal without providing a reason")
      end

      # Archive the goal
      update_params = {
        status: "archived",
        archived_at: Time.current
      }

      # Add clinical note if provided
      if reason.present?
        update_params[:clinical_note] = [ student_goal.clinical_note, "Removed: #{reason}" ].compact.join("\n")
      end

      # Track who removed it if available
      if current_user.present?
        update_params[:removed_by] = current_user.id if student_goal.respond_to?(:removed_by=)
      end

      student_goal.update!(update_params)

      success(student_goal)
    rescue => e
      failure(e.message)
    end
  end
end
