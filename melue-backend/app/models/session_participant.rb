# frozen_string_literal: true

class SessionParticipant < ApplicationRecord
  belongs_to :therapy_session
  belongs_to :student
  belongs_to :teacher_student_assignment
  belongs_to :current_focus_student_goal, class_name: "StudentGoal", optional: true

  has_many :trials, dependent: :restrict_with_error

  enum :card_position, { active: 0, secondary: 1 }, prefix: true

  validates :card_position, presence: true
  validates :therapy_session_id, uniqueness: {
    scope: :card_position,
    message: "already has a participant in this card position"
  }
  validates :student_id, uniqueness: {
    scope: :therapy_session_id,
    message: "is already a participant in this session"
  }
  validate :focus_goal_belongs_to_student

  # Returns the last N trials for this participant scoped to an optional goal
  def recent_trials(student_goal_id: nil, limit: 10)
    scope = trials.order(logged_at: :desc, id: :desc).limit(limit)
    scope = scope.where(student_goal_id: student_goal_id) if student_goal_id
    scope
  end

  private

  def focus_goal_belongs_to_student
    return unless current_focus_student_goal_id.present?

    unless StudentGoal.exists?(id: current_focus_student_goal_id, student_id: student_id)
      errors.add(:current_focus_student_goal_id, "must belong to this participant's student")
    end
  end
end
