# frozen_string_literal: true

class StaffMember < ApplicationRecord
  belongs_to :user

  has_many :teacher_student_assignments, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :therapy_sessions, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :goal_mastery_checks, foreign_key: :primary_teacher_id, dependent: :restrict_with_error

  enum :role, {
    teacher: "teacher",
    therapy_coordinator: "therapy_coordinator",
    program_director: "program_director",
    admin: "admin"
  }, prefix: true

  validates :full_name, presence: true
  validates :staff_number, presence: true, uniqueness: true
  validates :role, presence: true

  # ── RBAC Helpers ────────────────────────────────────────────────────────────

  # Directors, Admins, and Coordinators can see all students
  def can_view_all_students?
    role_admin? || role_program_director? || role_therapy_coordinator?
  end

  # Only Therapy Coordinators and Program Directors may edit students
  def can_edit_students?
    role_therapy_coordinator? || role_program_director?
  end

  # ── Domain Helpers ──────────────────────────────────────────────────────────

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

