# frozen_string_literal: true

# One preference assessment per assessment cycle (FR-047, FR-049).
#
# Held as a draft while the teacher works through the three contexts, then
# submitted once (FR-036). Observations carry the actual measurements.
class PreferenceAssessment < ApplicationRecord
  include Discard::Model

  # The three observation contexts defined by FR-047.
  CONTEXTS = %w[sensory_time circle_time play_time].freeze

  belongs_to :assessment_cycle

  has_many :preference_observations, dependent: :destroy

  enum :status, { draft: "draft", submitted: "submitted" }, prefix: true

  validates :status, presence: true
  validates :assessment_cycle_id, uniqueness: true

  delegate :student, :student_id, to: :assessment_cycle

  # Ranked observations, best first. Unranked rows sort last so a freshly
  # created observation never displaces a scored one.
  def ranked_observations(context: nil, limit: nil)
    scope = preference_observations.ranked.includes(:preference_inventory_item)
    scope = scope.where(context: context) if context.present?
    scope = scope.limit(limit) if limit
    scope
  end
end
