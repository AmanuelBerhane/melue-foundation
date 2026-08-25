# frozen_string_literal: true

class StaffMember < ApplicationRecord
  include Discard::Model

  belongs_to :user

  has_many :teacher_student_assignments, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :therapy_sessions, foreign_key: :teacher_id, dependent: :restrict_with_error
  has_many :goal_mastery_checks, foreign_key: :primary_teacher_id, dependent: :restrict_with_error
  has_many :ablls_assessments, dependent: :restrict_with_error

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

  def current_assignment_count_for_date(date, block_id = nil)
    scope = teacher_student_assignments.scheduled.where(scheduled_date: date)
    scope = scope.where(session_block_definition_id: block_id) if block_id
    scope.count
  end

  def available_for_date?(date, block_id = nil)
    capacity_config = SessionScheduleConfig.instance
    max_capacity = capacity_config.staff_to_student_capacity
    current_count = current_assignment_count_for_date(date, block_id)
    current_count < max_capacity
  end
end
