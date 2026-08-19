# frozen_string_literal: true

# A student's ABLLS assessment within a six-week assessment cycle (FR-037–FR-040).
#
# Exactly one ABLLS assessment exists per assessment cycle. The assessment tracks
# the teacher who conducts it, supports draft/resume behaviour, and must be
# explicitly completed once all items are evaluated.
class AbllsAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :assessment_cycle
  belongs_to :staff_member

  has_many :ablls_responses, dependent: :destroy

  enum :status, {
    draft:       "draft",
    in_progress: "in_progress",
    completed:   "completed"
  }, prefix: true

  validates :status, presence: true
  validates :assessment_cycle_id, uniqueness: true

  delegate :student, :student_id, to: :assessment_cycle

  # Returns true if this assessment can still be modified.
  def modifiable?
    !status_completed?
  end
end
