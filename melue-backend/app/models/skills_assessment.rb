# frozen_string_literal: true

class SkillsAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :assessment_cycle

  # Keep string statuses to match PreferenceAssessment / AssessmentCycle style
  STATUSES = %w[draft in_progress submitted].freeze

  validates :assessment_cycle_id, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :progress_percent, numericality: { only_integer: true, in: 0..100 }

  scope :kept, -> { undiscarded }   # explicit for clarity

  after_save :maybe_complete_cycle, if: :saved_change_to_status?

  def draft?        = status == "draft"
  def in_progress?  = status == "in_progress"
  def submitted?    = status == "submitted"

  private

  def maybe_complete_cycle
    assessment_cycle.check_and_mark_complete! if submitted?
  end
end
