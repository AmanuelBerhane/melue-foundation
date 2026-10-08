# app/models/fast_assessment.rb
class FastAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :student
  belongs_to :assessment_cycle, optional: true
  belongs_to :teacher, class_name: "StaffMember", optional: true

  enum :status, { draft: "draft", completed: "completed" }, prefix: true

  validates :status, presence: true
  validates :completed_at, presence: true, if: -> { status_completed? }

  # Store FAST responses as JSON
  # Each question: { question_id: true/false }
  store :responses, coder: JSON

  # Store calculated risk indicators
  store :risk_indicators, coder: JSON

  scope :completed, -> { where(status: "completed") }
  scope :for_student, ->(student_id) { where(student_id: student_id) }

  def self.truthy_response?(val)
    return false if val.nil?
    return true if val == true || val == 1
    return false if val == false || val == 0

    str = val.to_s.strip.downcase
    %w[true yes y 1 on].include?(str)
  end

  def completed?
    status_completed?
  end

  def draft?
    status_draft?
  end

  # FAST risk calculation
  RISK_QUESTIONS = {
    high: [ 1, 2, 3, 4, 5, 6, 7, 8 ],
    moderate: [ 9, 10, 11, 12, 13, 14, 15, 16 ]
  }.freeze

  # SCR-TEA-003 F1..F8 categories and functions
  F_FUNCTION_MAPPING = {
    attention: [ "F1", "F7" ],
    escape:    [ "F2", "F6" ],
    sensory:   [ "F3", "F4", "F5" ],
    tangible:  [ "F8" ]
  }.freeze

  F_CATEGORY_MAPPING = {
    "Social - Positive"   => [ "F1", "F7", "F8" ],
    "Social - Negative"   => [ "F2", "F6" ],
    "Automatic - Positive" => [ "F3", "F5" ],
    "Automatic - Negative" => [ "F4" ]
  }.freeze

  def risk_indicators
    raw = super || {}
    (raw.is_a?(Hash) ? raw : {}).with_indifferent_access
  end

  def calculate_risks!
    raw = responses || {}
    resp = raw["fastAnswers"] || raw[:fastAnswers] || raw["responses"] || raw[:responses] || raw
    resp = resp.transform_keys(&:to_s) if resp.is_a?(Hash)
    resp ||= {}

    high_risk_count = 0
    moderate_risk_count = 0

    # 1. Standard 16-item calculation
    RISK_QUESTIONS[:high].each do |q_id|
      high_risk_count += 1 if FastAssessment.truthy_response?(resp[q_id.to_s])
    end

    RISK_QUESTIONS[:moderate].each do |q_id|
      moderate_risk_count += 1 if FastAssessment.truthy_response?(resp[q_id.to_s])
    end

    # 2. SCR-TEA-003 F1..F8 calculation
    # Social items (demand/interaction) count towards high risk, automatic towards moderate risk
    %w[F1 F2 F6 F7 F8].each do |k|
      high_risk_count += 1 if FastAssessment.truthy_response?(resp[k])
    end
    %w[F3 F4 F5].each do |k|
      moderate_risk_count += 1 if FastAssessment.truthy_response?(resp[k])
    end

    total = high_risk_count + moderate_risk_count
    is_short_scale = resp.keys.any? { |k| k.to_s.start_with?("F") }
    level = risk_level(high_risk_count, moderate_risk_count, is_short_scale)

    # 3. Calculate 4 motivation functions (Sensory, Escape, Attention, Tangible)
    sensory_score = 0
    escape_score = 0
    attention_score = 0
    tangible_score = 0

    # F1..F8 mapping
    sensory_score += 1 if FastAssessment.truthy_response?(resp["F3"])
    sensory_score += 1 if FastAssessment.truthy_response?(resp["F4"])
    sensory_score += 1 if FastAssessment.truthy_response?(resp["F5"])

    escape_score += 1 if FastAssessment.truthy_response?(resp["F2"])
    escape_score += 1 if FastAssessment.truthy_response?(resp["F6"])

    attention_score += 1 if FastAssessment.truthy_response?(resp["F1"])
    attention_score += 1 if FastAssessment.truthy_response?(resp["F7"])

    tangible_score += 1 if FastAssessment.truthy_response?(resp["F8"])

    # Standard 16 questions mapping
    [ 9, 10, 11, 12, 13, 14, 15, 16 ].each do |q|
      sensory_score += 1 if FastAssessment.truthy_response?(resp[q.to_s])
    end
    [ 5, 6, 7, 8 ].each do |q|
      escape_score += 1 if FastAssessment.truthy_response?(resp[q.to_s])
    end
    [ 1, 2 ].each do |q|
      attention_score += 1 if FastAssessment.truthy_response?(resp[q.to_s])
    end
    [ 3, 4 ].each do |q|
      tangible_score += 1 if FastAssessment.truthy_response?(resp[q.to_s])
    end

    # 4. Category scores
    social_positive = 0
    social_negative = 0
    auto_positive = 0
    auto_negative = 0

    social_positive += 1 if FastAssessment.truthy_response?(resp["F1"])
    social_positive += 1 if FastAssessment.truthy_response?(resp["F7"])
    social_positive += 1 if FastAssessment.truthy_response?(resp["F8"])

    social_negative += 1 if FastAssessment.truthy_response?(resp["F2"])
    social_negative += 1 if FastAssessment.truthy_response?(resp["F6"])

    auto_positive += 1 if FastAssessment.truthy_response?(resp["F3"])
    auto_positive += 1 if FastAssessment.truthy_response?(resp["F5"])

    auto_negative += 1 if FastAssessment.truthy_response?(resp["F4"])

    category_scores = {
      "Social - Positive"   => social_positive,
      "Social - Negative"   => social_negative,
      "Automatic - Positive" => auto_positive,
      "Automatic - Negative" => auto_negative
    }

    func_totals = {
      "Sensory"   => sensory_score,
      "Escape"    => escape_score,
      "Attention" => attention_score,
      "Tangible"  => tangible_score
    }
    hypothesized_function = func_totals.max_by { |_, v| v }&.first || "Sensory"

    self.risk_indicators = {
      high_risk_count: high_risk_count,
      moderate_risk_count: moderate_risk_count,
      total: total,
      risk_level: level,
      sensory: sensory_score,
      escape: escape_score,
      attention: attention_score,
      tangible: tangible_score,
      scores: {
        sensory: sensory_score,
        escape: escape_score,
        attention: attention_score,
        tangible: tangible_score
      },
      category_scores: category_scores,
      hypothesized_function: hypothesized_function
    }
    save! if persisted?
    risk_indicators
  end

  def risk_level(high_count, moderate_count, is_short_scale = false)
    total = high_count + moderate_count
    if is_short_scale
      if high_count >= 4 || total >= 6
        "high"
      elsif high_count >= 2 || total >= 3
        "moderate"
      else
        "low"
      end
    else
      if high_count >= 5 || total >= 10
        "high"
      elsif high_count >= 3 || total >= 6
        "moderate"
      else
        "low"
      end
    end
  end

  def high_risk?
    risk_indicators[:risk_level].to_s == "high"
  end

  def moderate_risk?
    risk_indicators[:risk_level].to_s == "moderate"
  end

  def low_risk?
    risk_indicators[:risk_level].to_s == "low"
  end

  def scores
    ind = risk_indicators
    if ind[:scores].present?
      ind[:scores]
    else
      {
        "sensory" => ind[:sensory] || 0,
        "escape" => ind[:escape] || 0,
        "attention" => ind[:attention] || 0,
        "tangible" => ind[:tangible] || 0
      }
    end
  end

  def function_scores
    scores.symbolize_keys
  end

  def hypothesized_function
    risk_indicators[:hypothesized_function] || "Sensory"
  end

  def as_json(options = {})
    super(options).merge(
      "risk_indicators" => risk_indicators,
      "scores" => scores,
      "function_scores" => function_scores,
      "hypothesized_function" => hypothesized_function
    )
  end

  def summary
    {
      id: id,
      student_name: student&.full_name,
      completed_at: completed_at,
      status: status,
      risk_indicators: risk_indicators,
      scores: scores,
      function_scores: function_scores,
      hypothesized_function: hypothesized_function
    }
  end
end
