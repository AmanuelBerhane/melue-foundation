# frozen_string_literal: true

# Root of the six-week assessment workflow for a student (FR-049).
#
# Only the parts needed by the Preference Assessment are modelled here. The
# skills and behaviour siblings, and the completion gating described in FR-050
# ("cannot complete until skills, behaviour and preference are submitted"),
# belong to their own tasks and are deliberately not implemented yet.
class AssessmentCycle < ApplicationRecord
  belongs_to :student

  has_one :preference_assessment, dependent: :destroy

  enum :status, {
    in_progress: "in_progress",
    complete: "complete",
    reviewed: "reviewed"
  }, prefix: true

  validates :status, presence: true
  validates :started_on, presence: true

  scope :in_progress, -> { where(status: "in_progress") }

  # Returns the cycle's preference assessment, creating the draft on first use.
  # Idempotent: repeat calls return the same record (FR-036 draft/resume).
  def preference_assessment!
    preference_assessment || create_preference_assessment!
  end
end
