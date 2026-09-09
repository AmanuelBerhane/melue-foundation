# frozen_string_literal: true

module AbllsAssessments
  # Calculates assessment completion percentage and domain-level progress (FR-040).
  #
  # A skill item is "completed" when it has any valid score (0, 1, 2, or N/A).
  # An unanswered item (nil score) is NOT completed.
  # N/A counts as completed because the teacher explicitly evaluated it.
  # Progress is NOT based on score totals — only on whether items are answered.
  class ProgressService < ApplicationService
    # @param ablls_assessment [AbllsAssessment]
    def initialize(ablls_assessment:)
      @assessment = ablls_assessment
    end

    def call
      responses = @assessment.ablls_responses
                             .includes(ablls_skill_item: :ablls_domain)

      overall = calculate_overall(responses)
      domains = calculate_domain_progress(responses)

      success(overall.merge(domains: domains))
    end

    private

    def calculate_overall(responses)
      total     = responses.size
      completed = responses.count { |r| r.score.present? }
      na_count  = responses.count { |r| r.score == "not_applicable" }
      unanswered = total - completed

      {
        total_items:           total,
        completed_items:       completed,
        unanswered_items:      unanswered,
        na_items:              na_count,
        completion_percentage: total.zero? ? 0 : ((completed.to_f / total) * 100).round
      }
    end

    def calculate_domain_progress(responses)
      grouped = responses.group_by { |r| r.ablls_skill_item.ablls_domain }

      grouped.map do |domain, domain_responses|
        total     = domain_responses.size
        completed = domain_responses.count { |r| r.score.present? }

        {
          domain_id:             domain.id,
          domain_code:           domain.code,
          domain_name:           domain.name,
          total_items:           total,
          completed_items:       completed,
          completion_percentage: total.zero? ? 0 : ((completed.to_f / total) * 100).round
        }
      end.sort_by { |d| AbllsDomain.find(d[:domain_id]).position }
    end
  end
end
