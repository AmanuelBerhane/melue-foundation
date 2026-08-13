# frozen_string_literal: true

class TeacherStudentAssignment < ApplicationRecord
  include Discard::Model

  belongs_to :teacher, class_name: "StaffMember"
  belongs_to :student
  belongs_to :session_block_definition
  belongs_to :therapy_station
  belongs_to :therapy_room

  has_one :session_participant, dependent: :restrict_with_error

  enum :status, {
    scheduled: "scheduled",
    cancelled: "cancelled",
    completed: "completed"
  }, prefix: true

  validates :scheduled_date, presence: true
  validates :status, presence: true

  scope :scheduled, -> { where(status: "scheduled") }
  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :for_today, -> { for_date(Date.current) }
  scope :for_teacher, ->(teacher_id) { where(teacher_id: teacher_id) }
  scope :for_block, ->(block_id) { where(session_block_definition_id: block_id) }
end
