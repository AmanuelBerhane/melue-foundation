# frozen_string_literal: true

class StudentGuardian < ApplicationRecord
  belongs_to :student
  belongs_to :guardian

  validates :relationship, presence: true
  validates :guardian_id, uniqueness: { scope: :student_id, message: "is already linked to this student" }
end
