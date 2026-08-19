# frozen_string_literal: true

# A teacher's score and optional note for a single ABLLS skill item (FR-038).
#
# Score values:
#   '0'              — Not yet demonstrated / Full Physical prompt (FP)
#   '1'              — Emerging / Inconsistent / Partial Physical (PP) or Gesture (G)
#   '2'              — Consistent / Mastered / Independent (+)
#   'not_applicable' — Not applicable for this student (N/A)
#   nil              — Unanswered (not yet evaluated)
#
# N/A is explicitly distinct from '0' — it means the skill does not apply and
# must not be treated as an area of need.
class AbllsResponse < ApplicationRecord
  VALID_SCORES = %w[0 1 2 not_applicable].freeze

  belongs_to :ablls_assessment
  belongs_to :ablls_skill_item

  validates :score, inclusion: { in: VALID_SCORES, message: "must be 0, 1, 2, or N/A" }, allow_nil: true
  validates :ablls_skill_item_id, uniqueness: {
    scope: :ablls_assessment_id,
    message: "already has a response in this assessment"
  }

  scope :scored,     -> { where.not(score: nil) }
  scope :unanswered, -> { where(score: nil) }
  scope :needs,      -> { where(score: %w[0 1]) }

  # Returns true if this response has been evaluated (including N/A).
  def completed?
    score.present?
  end

  # Returns true if this response counts toward need analysis.
  def need?
    score.in?(%w[0 1])
  end
end
