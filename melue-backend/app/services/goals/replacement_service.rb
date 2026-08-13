# app/services/goals/replacement_service.rb
module Goals
  class ReplacementService < ApplicationService
    attr_reader :student_goal, :new_goal_id, :current_user

    def initialize(student_goal, new_goal_id, current_user = nil)
      @student_goal = student_goal
      @new_goal_id = new_goal_id
      @current_user = current_user
    end

    def call
      return failure("Student goal not found") unless student_goal
      return failure("New goal not found") unless new_goal_exists?

      # Validate the new goal is active
      new_goal = Goal.find_by(id: new_goal_id, is_active: true)
      return failure("New goal is not active") unless new_goal

      # Archive the current goal
      student_goal.status = "archived"
      student_goal.clinical_note = "#{student_goal.clinical_note}\nReplaced with goal #{new_goal.id} at #{Time.current}"

      # Create new student goal for replacement
      new_student_goal = StudentGoal.new(
        student: student_goal.student,
        goal_id: new_goal_id,
        therapy_station_id: student_goal.therapy_station_id,
        iup: student_goal.iup,
        status: "active",
        progress_percent: 0,
        clinical_note: "Replacement for goal #{student_goal.goal_id} at #{Time.current}"
      )

      StudentGoal.transaction do
        student_goal.save!
        new_student_goal.save!
      end

      success({
        archived_goal: student_goal,
        new_goal: new_student_goal
      })
    rescue => e
      failure("Failed to replace goal: #{e.message}")
    end

    private

    def new_goal_exists?
      Goal.exists?(id: new_goal_id)
    end
  end
end
