# frozen_string_literal: true

module Iups
  class AssessmentSummaryBuilder < ApplicationService
    def initialize(assessment_cycle:)
      @assessment_cycle = assessment_cycle
    end

    def call
      success({
        skills_findings: extract_skills_findings,
        behavior_findings: extract_behavior_findings,
        preference_findings: extract_preference_findings,
        assessment_dates: extract_assessment_dates
      })
    end

    private

    def extract_skills_findings
      ablls = @assessment_cycle.ablls_assessment
      return "No skills assessment data" unless ablls&.completed_at

      response_count = ablls.ablls_responses.count
      scored_count = ablls.ablls_responses.where.not(score: nil).count

      "ABLLS Assessment completed: #{scored_count}/#{response_count} items scored"
    end

    # TODO: Implement behavior assessment summary extraction when SocialSkillsQuestionnaire
    # or BehaviorAssessment models are available. Currently returns a placeholder string.
    def extract_behavior_findings
      "Behavior assessment data pending implementation"
    end

    def extract_preference_findings
      preference = @assessment_cycle.preference_assessment
      return "No preference data" unless preference&.submitted_at

      highest_items = preference.preference_observations
        .where(tier: "highest")
        .order(rank: :asc)
        .limit(5)
        .map { |obs| obs.preference_inventory_item&.name || obs.custom_item_name }
        .compact

      highest_items.any? ? "Top preferences: #{highest_items.join(', ')}" : "No high-preference items identified"
    end

    def extract_assessment_dates
      {
        preference_completed: @assessment_cycle.preference_assessment&.submitted_at,
        ablls_completed: @assessment_cycle.ablls_assessment&.completed_at,
        cycle_completed: @assessment_cycle.completed_on
      }
    end
  end
end
