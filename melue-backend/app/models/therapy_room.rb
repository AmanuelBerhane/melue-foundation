# frozen_string_literal: true

class TherapyRoom < ApplicationRecord
  include Discard::Model

  belongs_to :therapy_station

  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :therapy_sessions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :therapy_station, presence: true
end
