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

  # FAST risk calculation
  RISK_QUESTIONS = {
    high: [ 1, 2, 3, 4, 5, 6, 7, 8 ],
    moderate: [ 9, 10, 11, 12, 13, 14, 15, 16 ]
  }

  def calculate_risks!
    high_risk_count = 0
    moderate_risk_count = 0

    RISK_QUESTIONS[:high].each do |q_id|
      high_risk_count += 1 if responses[q_id.to_s] == true
    end

    RISK_QUESTIONS[:moderate].each do |q_id|
      moderate_risk_count += 1 if responses[q_id.to_s] == true
    end

    self.risk_indicators = {
      high_risk_count: high_risk_count,
      moderate_risk_count: moderate_risk_count,
      total: high_risk_count + moderate_risk_count,
      risk_level: risk_level(high_risk_count, moderate_risk_count)
    }
    save!
    risk_indicators
  end

  def risk_level(high_count, moderate_count)
    total = high_count + moderate_count
    if high_count >= 5 || total >= 10
      "high"
    elsif high_count >= 3 || total >= 6
      "moderate"
    else
      "low"
    end
  end

  def high_risk?
    risk_indicators[:risk_level] == "high"
  end

  def moderate_risk?
    risk_indicators[:risk_level] == "moderate"
  end

  def low_risk?
    risk_indicators[:risk_level] == "low"
  end

  def summary
    {
      id: id,
      student_name: student&.full_name,
      completed_at: completed_at,
      status: status,
      risk_indicators: risk_indicators
    }
  end
end
