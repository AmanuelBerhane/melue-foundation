# frozen_string_literal: true

# Serializes a SessionParticipant with student card data, goal pills, and recent trial stream (FR-090, FR-091, FR-093).
class SessionParticipantSerializer < ApplicationSerializer
  # @param resource [SessionParticipant, Array<SessionParticipant>]
  # @param station_id [String] pre-loaded therapy_station_id from the session to avoid N+1
  def initialize(resource, station_id:)
    super(resource)
    @station_id = station_id
  end

  private

  def serialize(participant)
    {
      id: participant.id,
      card_position: participant.card_position,
      student: student_payload(participant.student),
      current_focus_student_goal_id: participant.current_focus_student_goal_id,
      goals: goal_pills(participant),
      recent_trials: recent_trials(participant)
    }
  end

  def student_payload(student)
    {
      id: student.id,
      full_name: student.full_name,
      therapy_group: student.therapy_group
    }
  end

  def goal_pills(participant)
    goals = participant.student.active_goals_for_station(@station_id)
    GoalPillSerializer.new(goals).as_json
  end

  def recent_trials(participant)
    TrialSerializer.new(participant.recent_trials(limit: 10)).as_json
  end
end
