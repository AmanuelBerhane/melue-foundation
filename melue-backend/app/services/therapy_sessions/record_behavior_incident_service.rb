# frozen_string_literal: true

module TherapySessions
  # Records a behavior incident within an active therapy session (FR-097, FR-098, FR-099).
  #
  # Enforces:
  # - Links the incident to the session, student, active goal, and teacher.
  # - If student is not specified, defaults to the session's active participant.
  # - If student_goal is not specified, automatically logs the active focus goal
  #   the student was working on in the session (FR-098c).
  # - Auto-populates behavior definitions and defaults if omitted (FR-098a).
  # - Defaults location to the session's therapy room.
  # - Defaults teacher to the session's assigned teacher if not explicitly given.
  class RecordBehaviorIncidentService < ApplicationService
    def initialize(session:, student_id: nil, student_goal_id: nil, staff_member: nil, incident_params: {})
      @session         = session
      @student_id      = student_id
      @student_goal_id = student_goal_id
      @staff_member    = staff_member
      @params          = incident_params.to_h.symbolize_keys
    end

    def call
      return failure("Session is required") unless @session

      participant = resolve_participant
      return failure("Student is not a participant in this therapy session") unless participant

      student = participant.student
      student_goal = resolve_student_goal(participant, student)

      # Build incident
      teacher = @staff_member || @session.teacher
      location = @params[:location].presence || @session.therapy_room&.name || "Therapy room"

      incident = BehaviorIncident.new(
        therapy_session: @session,
        student: student,
        student_goal: student_goal,
        staff_member: teacher,
        behavior_name: @params[:behavior_name],
        behavior_definition: @params[:behavior_definition],
        frequency: @params[:frequency],
        intensity: @params[:intensity],
        category: @params[:category],
        antecedent: @params[:antecedent],
        consequence: @params[:consequence],
        location: location,
        occurred_at: @params[:occurred_at] || Time.current,
        additional_notes: @params[:additional_notes]
      )

      # Auto-populate defaults if not given
      incident.set_defaults

      if incident.save
        success(incident)
      else
        failure(incident.errors.full_messages.join(", "))
      end
    end

    private

    def resolve_participant
      if @student_id.present?
        @session.session_participants.find_by(student_id: @student_id)
      else
        @session.active_participant || @session.session_participants.first
      end
    end

    def resolve_student_goal(participant, student)
      if @student_goal_id.present?
        StudentGoal.find_by(id: @student_goal_id, student_id: student.id)
      else
        # FR-098c: Log the active goal the student was working on at the time of the incident
        if participant.current_focus_student_goal_id.present?
          StudentGoal.find_by(id: participant.current_focus_student_goal_id, student_id: student.id)
        else
          # Fallback to active goal assigned to the student for this therapy station
          student.student_goals.where(
            therapy_station_id: @session.therapy_station_id,
            status: %w[active in_progress]
          ).order(updated_at: :desc).first
        end
      end
    end
  end
end
