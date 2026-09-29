# frozen_string_literal: true

class StudentGoal < ApplicationRecord
  include Discard::Model

  belongs_to :iup
  belongs_to :student
  belongs_to :goal
  belongs_to :therapy_station

  has_many :trials, dependent: :restrict_with_error
  has_many :session_participants, foreign_key: :current_focus_student_goal_id, dependent: :nullify
  has_many :student_goal_steps,
         -> { order(:step_number) },
         dependent: :destroy,
         inverse_of: :student_goal
  has_many :goal_mastery_checks, dependent: :destroy
  has_many :behavior_incidents, dependent: :nullify

  enum :status, {
    active: "active",
    in_progress: "in_progress",
    pending_approval: "pending_approval",
    mastered: "mastered",
    archived: "archived"
  }, prefix: true

  validates :status, presence: true
  validates :progress_percent, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }, allow_nil: true
  validate :student_matches_iup
  validate :max_two_goals_per_station, on: :create

  scope :active_or_in_progress, -> { where(status: %w[active in_progress]) }

  delegate :name, to: :goal, prefix: true
  delegate :goal_type, to: :goal

  def mastered?
    status == "mastered"
  end

  private

  def student_matches_iup
    return unless iup && student

    errors.add(:student_id, "must match IUP's student") if iup.student_id != student_id
  end

  def max_two_goals_per_station
    return unless iup && therapy_station

    existing_count = StudentGoal.where(
      iup: iup,
      therapy_station: therapy_station,
      status: "active"
    ).count

    errors.add(:base, "Maximum 2 active goals per station") if existing_count >= 2
  end
end
