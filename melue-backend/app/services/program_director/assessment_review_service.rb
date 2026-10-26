# frozen_string_literal: true

module ProgramDirector
  # FR-054: Assessment Review Screen listing service
  # Supports status filtering, pagination, deduplication by student, and eager loading of assessment cycles.
  class AssessmentReviewService < ApplicationService
    def initialize(status: nil, page: nil, per_page: nil)
      @status = status.presence
      @page = page.present? ? [ page.to_i, 1 ].max : 1
      @per_page = per_page.present? ? [ [ per_page.to_i, 1 ].max, 100 ].min : 20
    end

    def call
      # Order so complete/reviewed cycles take precedence over in_progress, and newest first
      scope = AssessmentCycle.kept
                             .joins(:student)
                             .where(students: { discarded_at: nil })
                             .includes(:student, :ablls_assessment, :preference_assessment)
                             .order(
                               Arel.sql("CASE WHEN assessment_cycles.status IN ('complete', 'reviewed') THEN 0 ELSE 1 END"),
                               updated_at: :desc,
                               created_at: :desc
                             )

      scope = scope.where(status: @status) if @status.present?

      # Deduplicate by student_id to ensure each student appears at most once in review queue
      all_cycles = scope.to_a.uniq(&:student_id)

      total_count = all_cycles.size
      total_pages = (total_count.to_f / @per_page).ceil

      paginated_cycles = all_cycles.slice((@page - 1) * @per_page, @per_page) || []

      student_ids = paginated_cycles.map(&:student_id).compact.uniq
      sensory_by_student = SensoryAssessment.where(student_id: student_ids).index_by(&:student_id)
      assignments_by_student = TeacherStudentAssignment.kept
                                                       .where(student_id: student_ids)
                                                       .includes(teacher: :user)
                                                       .order(scheduled_date: :desc)
                                                       .group_by(&:student_id)

      assessments_payload = paginated_cycles.filter_map do |cycle|
        serialize_cycle(
          cycle,
          sensory_by_student[cycle.student_id],
          assignments_by_student[cycle.student_id]&.first
        )
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

    def serialize_cycle(cycle, sensory, assignment)
      student = cycle.student
      return nil unless student && !student.discarded?

      skills_status, skills_progress = evaluate_skills_assessment(cycle.ablls_assessment)
      pref_status, pref_progress = evaluate_preference_assessment(cycle.preference_assessment)
      behavior_status, behavior_progress = evaluate_behavior_assessment(sensory)

      overall_progress = if cycle.status.in?(%w[complete reviewed])
                           100
                         else
                           ((skills_progress + pref_progress + behavior_progress) / 3.0).round.clamp(0, 100)
                         end

      therapist_name = assignment&.teacher&.full_name || "Assigned Clinician"

      group_display = case student.therapy_group
                      when "basic" then "Basic Group"
                      when "functional_living" then "Functional Living"
                      else student.therapy_group.presence&.humanize || "Station 1"
                      end

      program_display = case student.program_type
                        when "regular" then "Regular"
                        when "pulled_out" then "Pulled out"
                        else student.program_type.presence&.humanize || "Comprehensive ABA"
                        end

      completed_date_str = cycle.completed_on&.strftime("%Y-%m-%d") ||
                           (cycle.status.in?(%w[complete reviewed]) ? cycle.updated_at.strftime("%Y-%m-%d") : nil)

      {
        id: cycle.id,
        assessment_id: cycle.id,
        student_id: student.id,
        studentId: student.id,
        student_name: student.full_name,
        studentName: student.full_name,
        age: student.age || 6,
        program: program_display,
        programType: program_display,
        therapy_group: group_display,
        therapyGroup: group_display,
        therapist: therapist_name,
        therapist_name: therapist_name,
        status: cycle.status,
        assessment_progress: overall_progress,
        abllsPct: skills_progress > 0 ? skills_progress : (cycle.status.in?(%w[complete reviewed]) ? 100 : overall_progress),
        skills_assessment: skills_status,
        behavior_assessment: behavior_status,
        preference_assessment: pref_status,
        sessionStatus: cycle.status.in?(%w[complete reviewed]) ? "assigned" : "pending",
        created_at: cycle.created_at,
        completed_at: cycle.completed_on || (cycle.status.in?(%w[complete reviewed]) ? cycle.updated_at.to_date : nil),
        dateCompleted: completed_date_str
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
