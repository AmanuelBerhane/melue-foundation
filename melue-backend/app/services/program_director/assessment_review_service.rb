# frozen_string_literal: true

module ProgramDirector
  # FR-054: Assessment Review Screen listing service
  # Supports status filtering, pagination, and eager loading of assessment cycles.
  class AssessmentReviewService < ApplicationService
    def initialize(status: nil, page: nil, per_page: nil)
      @status = status.presence
      @page = page.present? ? [ page.to_i, 1 ].max : 1
      @per_page = per_page.present? ? [ [ per_page.to_i, 1 ].max, 100 ].min : 20
    end

    def call
      scope = AssessmentCycle.kept
                             .includes(:student, :ablls_assessment, :preference_assessment)
                             .order(started_on: :desc, created_at: :desc)

      scope = scope.where(status: @status) if @status.present?

      total_count = scope.count
      total_pages = (total_count.to_f / @per_page).ceil

      paginated_cycles = scope.offset((@page - 1) * @per_page).limit(@per_page)

      student_ids = paginated_cycles.map(&:student_id).compact.uniq
      sensory_by_student = SensoryAssessment.where(student_id: student_ids).index_by(&:student_id)

      assessments_payload = paginated_cycles.map do |cycle|
        serialize_cycle(cycle, sensory_by_student[cycle.student_id])
      end

      success({
        assessments: assessments_payload,
        pagination: {
          current_page: @page,
          per_page: @per_page,
          total_count: total_count,
          total_pages: total_pages
        }
      })
    end

    private

    def serialize_cycle(cycle, sensory)
      student = cycle.student

      skills_status, skills_progress = evaluate_skills_assessment(cycle.ablls_assessment)
      pref_status, pref_progress = evaluate_preference_assessment(cycle.preference_assessment)
      behavior_status, behavior_progress = evaluate_behavior_assessment(sensory)

      overall_progress = if cycle.status.in?(%w[complete reviewed])
                           100
      else
                           ((skills_progress + pref_progress + behavior_progress) / 3.0).round.clamp(0, 100)
      end

      {
        id: cycle.id,
        assessment_id: cycle.id,
        student_id: student&.id,
        student_name: student&.full_name,
        status: cycle.status,
        assessment_progress: overall_progress,
        skills_assessment: skills_status,
        behavior_assessment: behavior_status,
        preference_assessment: pref_status,
        created_at: cycle.created_at,
        completed_at: cycle.completed_on
      }
    end

    def evaluate_skills_assessment(ablls)
      return [ "not_started", 0 ] unless ablls

      if ablls.status_completed?
        [ "complete", 100 ]
      else
        progress_res = AbllsAssessments::ProgressService.call(ablls_assessment: ablls)
        pct = progress_res.success? ? progress_res.data[:completion_percentage] : 0
        status = pct > 0 ? "in_progress" : "not_started"
        [ status, pct ]
      end
    end

    def evaluate_preference_assessment(preference)
      return [ "not_started", 0 ] unless preference

      if preference.status_submitted?
        [ "complete", 100 ]
      else
        has_obs = preference.preference_observations.any?
        [ has_obs ? "in_progress" : "not_started", has_obs ? 50 : 0 ]
      end
    end

    def evaluate_behavior_assessment(sensory)
      return [ "not_started", 0 ] unless sensory

      if sensory.status == "complete"
        [ "complete", 100 ]
      else
        [ "in_progress", 50 ]
      end
    end
  end
end
