# frozen_string_literal: true

# Serializes a SessionParticipant with student card data, goal pills, and recent trial stream (FR-090, FR-091, FR-093).
class SessionParticipantSerializer < ApplicationSerializer
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
    # Assumes the session's station context is accessible through association
    station_id = participant.therapy_session.therapy_station_id
    goals = participant.student.active_goals_for_station(station_id)
    GoalPillSerializer.new(goals).as_json
  end

  def recent_trials(participant)
    trials = participant.recent_trials(limit: 10)
    TrialSerializer.new(trials).as_json
  end
end
