# frozen_string_literal: true

# Root of the six-week assessment workflow for a student (FR-049).
#
# Completion gating described in FR-050 ("cannot complete until skills,
# behaviour and preference are submitted") is enforced by
# #check_and_mark_complete!, triggered when a skills or behaviour assessment
# is submitted.
class AssessmentCycle < ApplicationRecord
  include Discard::Model

  belongs_to :student

  has_one :preference_assessment, dependent: :destroy
  has_one :skills_assessment,   dependent: :destroy
  has_one :behavior_assessment, dependent: :destroy

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

  def find_or_build_assessment(type)
    case type.to_s
    when "skills", "ablls"
      skills_assessment || build_skills_assessment
    when "behavior"
      behavior_assessment || build_behavior_assessment
    when "preference"
      preference_assessment || build_preference_assessment
    else
      raise ArgumentError, "Unknown assessment type: #{type}"
    end
  end

  def check_and_mark_complete!
    return if status == "complete"

    all_done = [
      skills_assessment&.submitted?,
      behavior_assessment&.submitted?,
      preference_assessment&.status == "submitted"
    ].all?

    update!(status: "complete", completed_on: Date.current) if all_done
  end
end
