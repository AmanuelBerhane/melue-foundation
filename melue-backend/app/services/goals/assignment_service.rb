# app/services/goals/assignment_service.rb
module Goals
  class AssignmentService < ApplicationService
    MAX_GOALS_PER_STATION = 2

    attr_reader :student, :goal_id, :station_id, :iup_id, :notes, :current_user

    def initialize(student, goal_id, station_id, iup_id = nil, notes = nil, current_user = nil)
      @student = student
      @goal_id = goal_id
      @station_id = station_id
      @iup_id = iup_id
      @notes = notes
      @current_user = current_user
    end

    def call
      return failure("Student not found") unless student
      return failure("Goal not found") unless goal_exists?
      return failure("Station not found") unless station_exists?

      # If no IUP provided, use active IUP or create one
      iup = find_or_create_iup
      return failure(iup) unless iup.is_a?(Iup)

      # Check capacity
      capacity_check = check_capacity(iup)
      return capacity_check unless capacity_check.success?

      # Create student goal
      student_goal = StudentGoal.new(
        student: student,
        goal_id: goal_id,
        therapy_station_id: station_id,
        iup: iup,
        status: "active",
        clinical_note: notes,
        progress_percent: 0
      )

      if student_goal.save
        success(student_goal)
      else
        failure(student_goal.errors.full_messages.join(", "))
      end
    end

    private

    def goal_exists?
      Goal.exists?(id: goal_id, is_active: true)
    end

    def station_exists?
      TherapyStation.exists?(id: station_id)
    end

    def find_or_create_iup
      if iup_id.present?
        iup = Iup.find_by(id: iup_id, student_id: student.id)
        return failure("IUP not found for this student") unless iup
        return iup
      end

      # Try to find active IUP
      active_iup = student.active_iup
      return active_iup if active_iup

      # Create new IUP
      Iup.create!(
        student: student,
        status: "active"
      )
    rescue => e
      failure("Failed to create IUP: #{e.message}")
    end

    def check_capacity(iup)
      current_goals = StudentGoal
        .where(iup_id: iup.id)
        .where(therapy_station_id: station_id)
        .where.not(status: "archived")
        .count

      if current_goals >= MAX_GOALS_PER_STATION
        return failure("This station already has #{MAX_GOALS_PER_STATION} goals assigned. Replace an existing goal first.")
      end

      success
    end
  end
end
