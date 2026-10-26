# frozen_string_literal: true

class BehaviorTargetAssessment < ApplicationRecord
  include Discard::Model

  belongs_to :behavior_assessment

  STATUSES = %w[draft in_progress completed submitted].freeze

  validates :behavior_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  store :mass_responses, coder: JSON
  store :fast_responses, coder: JSON
  store :function_scores, coder: JSON
  store :risk_indicators, coder: JSON

  scope :for_behavior, ->(name) { where("lower(behavior_name) = ?", name.to_s.strip.downcase) }

  def draft? = status == "draft"
  def completed? = status == "completed" || status == "submitted"

  def calculate_function_scores!
    mass_resp = (mass_responses || {}).transform_keys(&:to_s)
    fast_resp = (fast_responses || {}).transform_keys(&:to_s)

    scores = { sensory: 0, escape: 0, attention: 0, tangible: 0 }

    # MASS calculation (M1..M12)
    MassAssessment::M_FUNCTION_MAPPING.each do |func, keys|
      keys.each do |k|
        if mass_resp.key?(k)
          scores[func] += MassAssessment.parse_likert_value(mass_resp[k])
        end
      end
    end

    # Standard numeric keys (1..20) fallback
    MassAssessment::FUNCTION_MAPPING.each do |func, keys|
      keys.each do |k|
        if mass_resp.key?(k.to_s)
          scores[func] += MassAssessment.parse_likert_value(mass_resp[k.to_s])
        end
      end
    end

    # FAST calculation (Yes answers contribute to corresponding functions)
    fast_resp.each do |k, v|
      is_yes = v == true || v.to_s.downcase == "yes" || v == 1 || v == "1"
      next unless is_yes

      case k.to_s.upcase
      when "F3", "F4", "F5"
        scores[:sensory] += 1
      when "F2", "F6"
        scores[:escape] += 1
      when "F1", "F7"
        scores[:attention] += 1
      when "F8"
        scores[:tangible] += 1
      end
    end

    self.function_scores = scores
    self.dominant_function = scores.max_by { |_, v| v }&.first&.to_s&.capitalize || "Sensory"
    self.hypothesized_function = dominant_function

    total_yes = fast_resp.values.count { |v| v == true || v.to_s.downcase == "yes" || v == 1 || v == "1" }
    risk_level = total_yes >= 5 ? "high" : (total_yes >= 2 ? "moderate" : "low")
    self.risk_indicators = {
      sensory: scores[:sensory],
      escape: scores[:escape],
      attention: scores[:attention],
      tangible: scores[:tangible],
      total_yes: total_yes,
      risk_level: risk_level
    }
  end
end
