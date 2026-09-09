# frozen_string_literal: true

module AbllsAssessments
  # Generates the automatic Need Analysis Summary (FR-039).
  #
  # The analysis highlights domains with the most scores of 0 and 1, which
  # represent areas of need. Domains are ranked by need_count descending.
  #
  # Rules:
  #   - need_count = score_0_count + score_1_count
  #   - N/A does NOT count as a need
  #   - Unanswered items do NOT count as needs
  #   - Score 2 does NOT count as a need
  #   - Domains with no answered items are NOT ranked as high-need
  #   - If no scores exist, return an empty/neutral summary
  class NeedAnalysisService < ApplicationService
    # @param ablls_assessment [AbllsAssessment]
    def initialize(ablls_assessment:)
      @assessment = ablls_assessment
    end

    def call
      responses = @assessment.ablls_responses
                             .includes(ablls_skill_item: :ablls_domain)

      domains = analyze_by_domain(responses)

      success(domains: domains)
    end

    private

    def analyze_by_domain(responses)
      grouped = responses.group_by { |r| r.ablls_skill_item.ablls_domain }

      domain_analyses = grouped.map do |domain, domain_responses|
        scored_responses = domain_responses.select { |r| r.score.present? }

        score_0_count = scored_responses.count { |r| r.score == "0" }
        score_1_count = scored_responses.count { |r| r.score == "1" }
        score_2_count = scored_responses.count { |r| r.score == "2" }
        na_count      = scored_responses.count { |r| r.score == "not_applicable" }
        need_count    = score_0_count + score_1_count

        {
          domain_id:            domain.id,
          domain_code:          domain.code,
          domain_name:          domain.name,
          total_items:          domain_responses.size,
          scored_items:         scored_responses.size,
          score_0_count:        score_0_count,
          score_1_count:        score_1_count,
          score_2_count:        score_2_count,
          not_applicable_count: na_count,
          need_count:           need_count
        }
      end

      # Rank by need_count descending; only include domains with scored items
      domain_analyses
        .select { |d| d[:scored_items] > 0 }
        .sort_by { |d| -d[:need_count] }
    end
  end
end
