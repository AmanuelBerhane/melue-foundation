# frozen_string_literal: true

class Trial < ApplicationRecord
  include Discard::Model

  belongs_to :therapy_session
  belongs_to :session_participant
  belongs_to :student_goal
  belongs_to :prompt_level

  # student_goal_step is optional — required only for task_analysis goals
  belongs_to :student_goal_step, optional: true

  enum :outcome, {
    correct: "correct",
    incorrect: "incorrect",
    no_response: "no_response"
  }, prefix: true

  validates :outcome, presence: true
  validates :logged_at, presence: true
  validates :prompt_label_snapshot, presence: true
  validates :client_event_id, presence: true, uniqueness: true
  validate :participant_belongs_to_session
  validate :goal_belongs_to_participant_student
  validate :step_matches_goal_type

  # Trials are append-only — no updates allowed after creation
  before_update { raise ActiveRecord::ReadOnlyRecord, "trials are immutable" }

  private

  def participant_belongs_to_session
    return unless therapy_session_id && session_participant_id

    unless session_participant&.therapy_session_id == therapy_session_id
      errors.add(:session_participant_id, "must belong to this session")
    end
  end

  def goal_belongs_to_participant_student
    return unless session_participant && student_goal

    unless student_goal.student_id == session_participant.student_id
      errors.add(:student_goal_id, "must belong to this participant's student")
    end
  end

  def step_matches_goal_type
    return unless student_goal

    goal = student_goal.goal
    if goal.goal_type == "standard" && student_goal_step_id.present?
      errors.add(:student_goal_step_id, "must be blank for standard goals")
    elsif goal.goal_type == "task_analysis" && student_goal_step_id.blank?
      errors.add(:student_goal_step_id, "must be present for task analysis goals")
    end
  end
end
