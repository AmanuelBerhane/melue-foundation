# frozen_string_literal: true

class StaffMember < ApplicationRecord
  include Discard::Model

  belongs_to :user

  has_many :teacher_student_assignments, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :therapy_sessions, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :goal_mastery_checks, foreign_key: :primary_teacher_id, dependent: :restrict_with_error

  validates :full_name, presence: true
  validates :staff_number, presence: true, uniqueness: true

  # Returns the currently active (in_progress) session for this staff member
  def active_session
    therapy_sessions.find_by(status: :in_progress)
  end

  # Returns today's assignments for a given block definition
  def todays_assignments(block_definition_id)
    teacher_student_assignments
      .where(scheduled_date: Date.current, session_block_definition_id: block_definition_id, status: :scheduled)
  end
end
