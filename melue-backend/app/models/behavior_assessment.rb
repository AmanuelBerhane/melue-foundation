# frozen_string_literal: true

class BehaviorAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :assessment_cycle

  has_many :behavior_target_assessments, dependent: :destroy
  has_many :behavior_questionnaire_records, class_name: "BehaviorTargetAssessment", dependent: :destroy

  STATUSES = %w[draft in_progress submitted completed].freeze

  validates :assessment_cycle_id, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  after_save :maybe_complete_cycle, if: :saved_change_to_status?

  def draft?        = status == "draft"
  def in_progress?  = status == "in_progress"
  def submitted?    = status == "submitted" || status == "completed"
  def completed?    = status == "completed" || status == "submitted"

  private

  def maybe_complete_cycle
    assessment_cycle.check_and_mark_complete! if submitted?
  end
end
