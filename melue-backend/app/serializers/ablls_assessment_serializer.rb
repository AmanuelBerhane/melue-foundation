# frozen_string_literal: true

# Serializes the full ABLLS assessment payload for the SCR-TEA-002 screen.
#
# Composes: assessment metadata, student, progress, score options,
# domains with items and responses, and need analysis summary.
class AbllsAssessmentSerializer < ApplicationSerializer
  # Score metadata exposed to the frontend so the UI does not duplicate
  # clinical definitions (FR-038a, FR-038b).
  SCORE_OPTIONS = [
    { value: "0", label: "Not yet demonstrated", prompt: "FP", color: "#EF4444" }.freeze,
    { value: "1", label: "Emerging / Inconsistent", prompt: "PP / G", color: "#F59E0B" }.freeze,
    { value: "2", label: "Consistent / Mastered", prompt: "+", color: "#22C55E" }.freeze,
    { value: "not_applicable", label: "Not applicable", prompt: nil, color: "#9CA3AF" }.freeze
  ].freeze

  private

  def serialize(assessment)
    progress_result = AbllsAssessments::ProgressService.call(ablls_assessment: assessment)
    need_result     = AbllsAssessments::NeedAnalysisService.call(ablls_assessment: assessment)

    progress_data = progress_result.data
    need_data     = need_result.data

    {
      assessment: serialize_assessment(assessment),
      student:    serialize_student(assessment.student),
      progress:   serialize_progress(progress_data),
      score_options: SCORE_OPTIONS,
      domains:    serialize_domains(assessment),
      need_analysis: need_data
    }
  end

  def serialize_assessment(assessment)
    {
      id:           assessment.id,
      type:         "ablls",
      status:       assessment.status,
      started_at:   assessment.started_at,
      completed_at: assessment.completed_at,
      created_at:   assessment.created_at,
      updated_at:   assessment.updated_at
    }
  end

  def serialize_student(student)
    {
      id:        student.id,
      full_name: student.full_name
    }
  end

  def serialize_progress(progress_data)
    {
      total_items:           progress_data[:total_items],
      completed_items:       progress_data[:completed_items],
      unanswered_items:      progress_data[:unanswered_items],
      na_items:              progress_data[:na_items],
      completion_percentage: progress_data[:completion_percentage]
    }
  end

  def serialize_domains(assessment)
    # Eager-load responses indexed by skill item id for O(1) lookup
    responses_by_item = assessment.ablls_responses
                                  .index_by(&:ablls_skill_item_id)

    AbllsDomain.active.ordered.includes(:ablls_skill_items).map do |domain|
      items = domain.ablls_skill_items.select(&:is_active).sort_by(&:position)
      domain_responses = items.map { |item| responses_by_item[item.id] }.compact
      scored_count = domain_responses.count { |r| r.score.present? }

      {
        id:                    domain.id,
        code:                  domain.code,
        name:                  domain.name,
        position:              domain.position,
        total_items:           items.size,
        scored_items:          scored_count,
        completion_percentage: items.size.zero? ? 0 : ((scored_count.to_f / items.size) * 100).round,
        items: items.map do |item|
          response = responses_by_item[item.id]
          {
            id:          item.id,
            identifier:  item.identifier,
            description: item.description,
            response_id: response&.id,
            score:       response&.score,
            note:        response&.note,
            updated_at:  response&.updated_at
          }
        end
      }
    end
  end
end
