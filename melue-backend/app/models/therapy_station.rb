# frozen_string_literal: true

class TherapyStation < ApplicationRecord
  include Discard::Model

  has_many :therapy_rooms, dependent: :restrict_with_error
  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :therapy_sessions, dependent: :restrict_with_error
  has_many :student_goals, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :active, -> { all } # All stations are active by default; add is_active if needed
end
