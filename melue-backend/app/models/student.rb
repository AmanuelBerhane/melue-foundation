# frozen_string_literal: true

class Student < ApplicationRecord
  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :session_participants, dependent: :restrict_with_error
  has_many :iups, dependent: :restrict_with_error
  has_many :student_goals, dependent: :restrict_with_error

  enum :program_type, { regular: "regular", pulled_out: "pulled_out" }, prefix: true
  enum :therapy_group, { basic: "basic", functional_living: "functional_living" }, prefix: true
  enum :status, {
    in_assessment: "in_assessment",
    assessment_complete: "assessment_complete",
    ready_for_iup: "ready_for_iup",
    active_therapy: "active_therapy",
    withdrawn: "withdrawn",
    discharged: "discharged"
  }, prefix: true

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :date_of_birth, presence: true
  validates :program_type, presence: true
  validates :therapy_group, presence: true
  validates :status, presence: true

  def full_name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  # Returns the single active IUP for this student
  def active_iup
    iups.find_by(status: "active")
  end

  # Returns active student goals for a specific station
  def active_goals_for_station(therapy_station_id)
    student_goals.where(therapy_station_id: therapy_station_id, status: %w[active in_progress])
  end
end
