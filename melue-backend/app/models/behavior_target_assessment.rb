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
  store_accessor :function_scores, :definition

  scope :for_behavior, ->(name) { where("lower(behavior_name) = ?", name.to_s.strip.downcase) }

  def draft? = status == "draft"
  def completed? = status == "completed" || status == "submitted"

  # Authentic 16-Item MAS Category Mappings (Delaney & Durand, 1986)
  MAS_CATEGORY_MAPPING = {
    sensory: [1, 5, 9, 13].freeze,
    escape: [2, 6, 10, 14].freeze,
    attention: [3, 7, 11, 15].freeze,
    tangible: [4, 8, 12, 16].freeze
  }.freeze

  MAS_CATEGORY_NAMES = {
    sensory: "Sensory",
    escape: "Escape",
    attention: "Attention",
    tangible: "Tangible"
  }.freeze

  # Authentic FAST Category Mappings (27 Questions - Florida Center on Self-Injury)
  FAST_CATEGORY_MAPPING = {
    social_attention: { part_two_items: [4, 5, 6, 7, 8], max: 8, label: "Social Reinforcement — Attention" }.freeze,
    social_tangible:  { part_two_items: [9, 10, 11, 12, 13], max: 8, label: "Social Reinforcement — Tangible" }.freeze,
    social_escape:    { part_two_items: [14, 15, 16, 17, 18], max: 8, label: "Social Reinforcement — Escape" }.freeze,
    automatic_sensory: { items: [19, 20, 21, 22, 23, 24], max: 6, label: "Automatic Reinforcement — Sensory Stimulation" }.freeze,
    automatic_pain:   { items: [19, 20, 24, 25, 26, 27], max: 6, label: "Automatic Reinforcement — Pain Attenuation" }.freeze
  }.freeze

  def self.parse_likert(val)
    return 0 if val.nil?
    return val.to_i.clamp(0, 6) if val.is_a?(Numeric)
    str = val.to_s.strip
    return str.to_i.clamp(0, 6) if str =~ /\A\d+\z/
    {
      "never" => 0,
      "almost never" => 1,
      "seldom" => 2,
      "half the time" => 3,
      "usually" => 4,
      "almost always" => 5,
      "always" => 6
    }[str.downcase] || 0
  end

  def self.truthy_fast?(val)
    return false if val.nil?
    return true if val == true || val == 1
    return false if val == false || val == 0
    str = val.to_s.strip.downcase
    %w[true yes y 1 on].include?(str)
  end

  def calculate_function_scores!
    mass_resp = (mass_responses || {}).transform_keys(&:to_s)
    fast_resp = (fast_responses || {}).transform_keys(&:to_s)

    # 1. Exact 16-Item MAS 4-Category Calculation
    mas_scores_result = {}
    mas_totals = {}
    mas_means = {}

    MAS_CATEGORY_MAPPING.each do |cat, q_nums|
      total = 0
      q_nums.each do |n|
        val = mass_resp["M#{n}"] || mass_resp[n.to_s]
        total += self.class.parse_likert(val) if val.present?
      end

      item_count = q_nums.size
      mean = (total.to_f / item_count).round(2)
      mas_totals[cat] = total
      mas_means[cat] = mean

      mas_scores_result[cat] = {
        label: MAS_CATEGORY_NAMES[cat],
        total: total,
        item_count: item_count,
        mean: mean,
        rank: 1
      }
    end

    # Motivational Ranking: Rank 1 (highest mean) to Rank 4 (lowest mean)
    sorted_cats = mas_scores_result.keys.sort_by { |cat| [-mas_scores_result[cat][:mean], -mas_scores_result[cat][:total]] }
    sorted_cats.each_with_index do |cat, idx|
      mas_scores_result[cat][:rank] = idx + 1
    end

    primary_mas_category = sorted_cats.first
    primary_mas_label = MAS_CATEGORY_NAMES[primary_mas_category] || "Sensory"

    # 2. Exact FAST 27-Item Calculation with Part I Social Gating
    part_one_yes_count = (1..3).count { |n| self.class.truthy_fast?(fast_resp["F#{n}"] || fast_resp[n.to_s]) }
    has_social_influence = part_one_yes_count > 0

    fast_scores_result = {}
    fast_counts = {}
    max_pct = -1

    FAST_CATEGORY_MAPPING.each do |cat, meta|
      yes_count = 0
      if meta[:part_two_items]
        # Include Part I items 1-3 if any was answered Yes
        yes_count += part_one_yes_count if has_social_influence
        meta[:part_two_items].each do |n|
          val = fast_resp["F#{n}"] || fast_resp[n.to_s]
          yes_count += 1 if self.class.truthy_fast?(val)
        end
      else
        meta[:items].each do |n|
          val = fast_resp["F#{n}"] || fast_resp[n.to_s]
          yes_count += 1 if self.class.truthy_fast?(val)
        end
      end

      pct = meta[:max] > 0 ? ((yes_count.to_f / meta[:max]) * 100).round(1) : 0
      max_pct = [max_pct, pct].max
      fast_counts[cat] = yes_count

      fast_scores_result[cat] = {
        label: meta[:label],
        yes_count: yes_count,
        max_points: meta[:max],
        percentage: pct,
        is_dominant: false
      }
    end

    dominant_fast_vars = []
    if max_pct > 0
      fast_scores_result.each do |_cat, data|
        if data[:percentage] == max_pct
          data[:is_dominant] = true
          dominant_fast_vars << data[:label]
        end
      end
    end

    # 3. Overall 4-Function Composite (Sensory, Escape, Attention, Tangible)
    composite = {
      sensory: mas_totals[:sensory].to_i + fast_counts[:automatic_sensory].to_i,
      escape: mas_totals[:escape].to_i + fast_counts[:social_escape].to_i,
      attention: mas_totals[:attention].to_i + fast_counts[:social_attention].to_i,
      tangible: mas_totals[:tangible].to_i + fast_counts[:social_tangible].to_i
    }

    self.function_scores = composite.merge(
      mas_scores: mas_scores_result,
      mas_ranking: sorted_cats.map { |c| mas_scores_result[c] },
      primary_maintaining_variable: primary_mas_label,
      fast_scores: fast_scores_result,
      dominant_fast_variables: dominant_fast_vars,
      part_one_social_yes_count: part_one_yes_count,
      has_social_influence: has_social_influence,
      definition: definition
    )

    self.dominant_function = primary_mas_label
    self.hypothesized_function = primary_mas_label

    total_yes = (1..27).count { |n| self.class.truthy_fast?(fast_resp["F#{n}"] || fast_resp[n.to_s]) }
    risk_level = total_yes >= 8 ? "high" : (total_yes >= 3 ? "moderate" : "low")
    self.risk_indicators = {
      sensory: composite[:sensory],
      escape: composite[:escape],
      attention: composite[:attention],
      tangible: composite[:tangible],
      total_yes: total_yes,
      risk_level: risk_level,
      dominant_fast_variables: dominant_fast_vars
    }
  end
end
