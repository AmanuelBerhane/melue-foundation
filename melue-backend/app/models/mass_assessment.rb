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

  # MASS Question categories for scoring
  FUNCTION_MAPPING = {
    sensory: [ 1, 4, 7, 10, 13 ],
    escape: [ 2, 5, 8, 11, 14 ],
    attention: [ 3, 6, 9, 12, 15 ],
    tangible: [ 16, 17, 18, 19, 20 ]
  }

  # Calculate function scores from responses
  def calculate_scores!
    scores = {
      sensory: 0,
      escape: 0,
      attention: 0,
      tangible: 0
    }

    FUNCTION_MAPPING.each do |function, question_ids|
      total = 0
      question_ids.each do |q_id|
        total += responses[q_id.to_s].to_i || 0
      end
      scores[function] = total
    end

    self.scores = scores
    save!
    scores
  end

  def function_scores
    if scores.present? && scores.any?
      scores
    else
      calculate_scores!
    end
  end

  def highest_function
    function_scores.max_by { |_key, value| value }
  end

  # Returns a summary for reporting
  def summary
    {
      id: id,
      student_name: student&.full_name,
      completed_at: completed_at,
      status: status,
      scores: function_scores,
      highest_function: highest_function
    }
  end
end
