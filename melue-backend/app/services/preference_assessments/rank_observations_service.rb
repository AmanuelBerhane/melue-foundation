# frozen_string_literal: true

module PreferenceAssessments
  # Recomputes combined score, rank and tier for a preference assessment
  # (FR-047c, FR-048).
  #
  # Ranking is per context — Sensory Time, Circle Time and Play Time are
  # separate observation sets and are never ranked against one another.
  #
  # Scoring
  # -------
  # Duration is in seconds and frequency is a count, so the two cannot be added
  # directly. Each is first normalised against the highest value recorded in
  # that context, giving a 0..1 figure, then combined:
  #
  #   combined_score = (0.6 * normalised_duration + 0.4 * normalised_frequency) * 100
  #
  # Duration carries the heavier weight because sustained engagement is the
  # stronger preference signal; frequency distinguishes items the student
  # returns to repeatedly. Both weights are constants so the clinical team can
  # retune them in one place.
  #
  # Tiers
  # -----
  # Engaged items are split into thirds — Highest / Moderately / Low Preferred,
  # mirroring the paper form's grouping. An item the student never engaged with
  # is always Low Preferred, whatever its position.
  class RankObservationsService < ApplicationService
    DURATION_WEIGHT  = 0.6
    FREQUENCY_WEIGHT = 0.4
    SCORE_SCALE      = 100.0
    SCORE_PRECISION  = 3

    # @param preference_assessment [PreferenceAssessment]
    # @param context [String, nil] rank a single context, or all three when nil
    def initialize(preference_assessment:, context: nil)
      @preference_assessment = preference_assessment
      @contexts = context.present? ? [ context ] : PreferenceAssessment::CONTEXTS
    end

    def call
      PreferenceAssessment.transaction do
        @contexts.each { |context| rank_context(context) }
      end

      success(@preference_assessment)
    end

    private

    def rank_context(context)
      observations = @preference_assessment
                       .preference_observations
                       .where(context: context)
                       .includes(:preference_inventory_item)
                       .to_a
      return if observations.empty?

      max_duration  = observations.map { |o| o.duration_seconds.to_i }.max
      max_frequency = observations.map { |o| o.frequency_count.to_i }.max

      ordered = observations
                  .map { |o| [ o, combined_score(o, max_duration, max_frequency) ] }
                  .sort_by { |observation, score| sort_key(observation, score) }

      engaged_count = ordered.count { |observation, _score| observation.engaged? }
      highest_cut, moderate_cut = tier_cutoffs(engaged_count)

      ordered.each_with_index do |(observation, score), index|
        rank = index + 1

        observation.update_columns(
          combined_score: score,
          rank:           rank,
          tier:           tier_for(observation, rank, highest_cut, moderate_cut),
          updated_at:     Time.current
        )
      end
    end

    def combined_score(observation, max_duration, max_frequency)
      duration  = normalize(observation.duration_seconds.to_i, max_duration)
      frequency = normalize(observation.frequency_count.to_i, max_frequency)

      score = (DURATION_WEIGHT * duration) + (FREQUENCY_WEIGHT * frequency)
      (score * SCORE_SCALE).round(SCORE_PRECISION)
    end

    def normalize(value, max)
      return 0.0 if max.to_i.zero?

      value.to_f / max
    end

    # Deterministic ordering: score first, then the raw signals, then item name
    # and id so a redundant re-rank never reshuffles equally scored items.
    def sort_key(observation, score)
      [
        -score,
        -observation.duration_seconds.to_i,
        -observation.frequency_count.to_i,
        observation.item_name.to_s.downcase,
        observation.id
      ]
    end

    # Splits the engaged items into three groups, rounding up so the top group
    # is never empty when at least one item was engaged with.
    def tier_cutoffs(engaged_count)
      return [ 0, 0 ] if engaged_count.zero?

      [ (engaged_count / 3.0).ceil, (engaged_count * 2 / 3.0).ceil ]
    end

    def tier_for(observation, rank, highest_cut, moderate_cut)
      return "low" unless observation.engaged?
      return "highest" if rank <= highest_cut
      return "moderate" if rank <= moderate_cut

      "low"
    end
  end
end
