# frozen_string_literal: true

class StudentGoal < ApplicationRecord
  include Discard::Model

  belongs_to :iup
  belongs_to :student
  belongs_to :goal
  belongs_to :therapy_station

  has_many :trials, dependent: :restrict_with_error
  has_many :session_participants, foreign_key: :current_focus_student_goal_id, dependent: :nullify
  has_many :goal_mastery_checks, dependent: :destroy

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

  scope :active_or_in_progress, -> { where(status: %w[active in_progress]) }

  delegate :name, to: :goal, prefix: true
  delegate :goal_type, to: :goal

  private

  def student_matches_iup
    return unless iup && student

    errors.add(:student_id, "must match IUP's student") if iup.student_id != student_id
  end
end
