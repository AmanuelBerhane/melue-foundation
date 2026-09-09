# frozen_string_literal: true

module ProgramDirector
  # FR-053: Assessment Pipeline Service
  # Computes each student's progress through the assessment workflow:
  # Assessment → Assessment Complete → Review → Ready for IUP
  class AssessmentPipelineService < ApplicationService
    def call
      students = Student.kept
                        .where(status: %w[in_assessment assessment_complete ready_for_iup])
                        .includes(
                          assessment_cycles: %i[ablls_assessment preference_assessment]
                        )
                        .order(:last_name, :first_name)

      # Also load sensory assessments to inform behavior status if available
      sensory_by_student = SensoryAssessment.where(student_id: students.map(&:id)).index_by(&:student_id)

      pipeline_data = students.map do |student|
        build_student_pipeline_data(student, sensory_by_student[student.id])
      end

      success(pipeline_data)
    end

    private

    def build_student_pipeline_data(student, sensory_assessment)
      cycle = student.assessment_cycles.max_by(&:started_on)

      skills_status, skills_progress = evaluate_skills_assessment(cycle&.ablls_assessment)
      pref_status, pref_progress = evaluate_preference_assessment(cycle&.preference_assessment)
      behavior_status, behavior_progress = evaluate_behavior_assessment(sensory_assessment)

      overall_progress = calculate_overall_progress(
        student_status: student.status,
        cycle_status: cycle&.status,
        skills_progress: skills_progress,
        pref_progress: pref_progress,
        behavior_progress: behavior_progress
      )

      stage = derive_stage(student.status, cycle&.status, overall_progress)

      {
        student_id: student.id,
        student_name: student.full_name,
        status: student.status,
        stage: stage,
        assessment_progress: overall_progress,
        skills_assessment: skills_status,
        behavior_assessment: behavior_status,
        preference_assessment: pref_status
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
        # Draft with observations is in_progress
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

    def calculate_overall_progress(student_status:, cycle_status:, skills_progress:, pref_progress:, behavior_progress:)
      if student_status.in?(%w[assessment_complete ready_for_iup]) || cycle_status.in?(%w[complete reviewed])
        return 100
      end

      # Weighted/averaged progress across existing assessments
      avg = ((skills_progress + pref_progress + behavior_progress) / 3.0).round
      avg.clamp(0, 100)
    end

    def derive_stage(student_status, cycle_status, progress)
      if student_status == "ready_for_iup"
        "Ready for IUP"
      elsif cycle_status == "reviewed"
        "Review"
      elsif student_status == "assessment_complete" || cycle_status == "complete" || progress >= 100
        "Ready for Review"
      else
        "Assessment"
      end
    end
  end
end
