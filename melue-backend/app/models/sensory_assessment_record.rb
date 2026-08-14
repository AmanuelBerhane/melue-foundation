class SensoryAssessmentRecord < ApplicationRecord
  belongs_to :sensory_assessment
  belongs_to :sensory_activity

  ENGAGEMENT_LEVELS = [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ].freeze
  RESPONSE_REACTIONS = [ "Enjoyed", "Neutral", "Refused", "Not Observed" ].freeze

  validates :engagement_level, inclusion: { in: ENGAGEMENT_LEVELS }, allow_nil: true
  validates :response_reaction, inclusion: { in: RESPONSE_REACTIONS }, allow_nil: true
end
