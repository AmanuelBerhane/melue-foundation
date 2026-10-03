# app/models/mass_assessment.rb
class MassAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :student
  belongs_to :assessment_cycle, optional: true
  belongs_to :teacher, class_name: "StaffMember", optional: true

  enum :status, { draft: "draft", completed: "completed" }, prefix: true

  validates :status, presence: true
  validates :completed_at, presence: true, if: -> { status_completed? }

  # Store MASS responses as JSON
  # Each question: { question_id: score (0-6) }
  store :responses, coder: JSON

  # Store calculated function scores
  store :scores, accessors: [
    :sensory, :escape, :attention, :tangible
  ], coder: JSON

  scope :completed, -> { where(status: "completed") }
  scope :for_student, ->(student_id) { where(student_id: student_id) }

  # SCR-TEA-003 Likert scale options mapping (0-6)
  LIKERT_MAP = {
    "never" => 0,
    "almost never" => 1,
    "seldom" => 2,
    "half the time" => 3,
    "usually" => 4,
    "almost always" => 5,
    "always" => 6
  }.freeze

  # SCR-TEA-003 MASS Items (M1..M12)
  M_FUNCTION_MAPPING = {
    sensory:   [ "M1", "M5", "M10" ],
    escape:    [ "M2", "M6", "M9" ],
    attention: [ "M3", "M7", "M11" ],
    tangible:  [ "M4", "M8", "M12" ]
  }.freeze

  # MASS Question categories for standard 20-question scoring
  FUNCTION_MAPPING = {
    sensory: [ 1, 4, 7, 10, 13 ],
    escape: [ 2, 5, 8, 11, 14 ],
    attention: [ 3, 6, 9, 12, 15 ],
    tangible: [ 16, 17, 18, 19, 20 ]
  }.freeze

  def self.parse_likert_value(val)
    return 0 if val.nil?
    return val.to_i.clamp(0, 6) if val.is_a?(Numeric)

    str = val.to_s.strip
    return str.to_i.clamp(0, 6) if str =~ /\A\d+\z/

    LIKERT_MAP[str.downcase] || 0
  end

  def completed?
    status_completed?
  end

  def draft?
    status_draft?
  end

  # Calculate function scores from responses
  def calculate_scores!
    raw = responses || {}
    resp = raw["massAnswers"] || raw[:massAnswers] || raw["responses"] || raw[:responses] || raw
    resp = resp.transform_keys(&:to_s) if resp.is_a?(Hash)
    resp ||= {}

    calc = {
      sensory: 0,
      escape: 0,
      attention: 0,
      tangible: 0
    }

    # 1. Check SCR-TEA-003 M-keys (M1..M12)
    M_FUNCTION_MAPPING.each do |func, keys|
      keys.each do |k|
        if resp.key?(k)
          calc[func] += MassAssessment.parse_likert_value(resp[k])
        end
      end
    end

    # 2. Check standard numeric keys (1..20)
    FUNCTION_MAPPING.each do |func, keys|
      keys.each do |k|
        if resp.key?(k.to_s)
          calc[func] += MassAssessment.parse_likert_value(resp[k.to_s])
        end
      end
    end

    self.scores = calc.transform_keys(&:to_s)
    save! if persisted?
    calc
  end

  def function_scores
    if scores.present? && scores.is_a?(Hash) && scores.key?("sensory")
      scores.symbolize_keys
    else
      calculate_scores!.symbolize_keys
    end
  end

  def highest_function
    function_scores.max_by { |_key, value| value } || [ :sensory, 0 ]
  end

  def dominant_function
    highest_function.first.to_s.titleize
  end

  def risk_indicators
    sc = function_scores
    total = sc.values.sum
    max_val = sc.values.max || 0
    level = if max_val >= 12 || total >= 24
              "high"
    elsif max_val >= 6 || total >= 12
              "moderate"
    else
              "low"
    end

    {
      "high_risk_count" => sc.values.count { |v| v >= 12 },
      "moderate_risk_count" => sc.values.count { |v| v.between?(6, 11) },
      "total" => total,
      "risk_level" => level,
      "dominant_function" => dominant_function,
      "scores" => sc.stringify_keys
    }.with_indifferent_access
  end

  def as_json(options = {})
    super(options).merge(
      "scores" => scores,
      "function_scores" => function_scores,
      "dominant_function" => dominant_function,
      "highest_function" => highest_function,
      "risk_indicators" => risk_indicators
    )
  end

  # Returns a summary for reporting
  def summary
    {
      id: id,
      student_name: student&.full_name,
      completed_at: completed_at,
      status: status,
      scores: function_scores,
      highest_function: highest_function,
      dominant_function: dominant_function,
      risk_indicators: risk_indicators
    }
  end
end
