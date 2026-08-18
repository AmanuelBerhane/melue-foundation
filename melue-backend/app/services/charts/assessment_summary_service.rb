# app/services/charts/assessment_summary_service.rb
module Charts
  class AssessmentSummaryService < ApplicationService
    attr_reader :student

    def initialize(student)
      @student = student
    end

    def call
      return failure("Student not found") unless student

      data = {
        student_id: student.id,
        student_name: student.full_name,
        assessments: {
          preference: get_preference_assessment,
          skills: get_ablls_assessment,
          behavior: get_behavior_assessment
        }
      }

      success(data)
    end

    private

    def get_preference_assessment
      assessment_cycle = student.assessment_cycles
        .includes(:preference_assessment)
        .where(preference_assessments: { status: "submitted" })
        .last

      return { available: false, message: "No submitted preference assessment found" } unless assessment_cycle

      preference = assessment_cycle.preference_assessment
      ranked = preference.ranked_observations(limit: 10)

      {
        available: true,
        submitted_at: preference.submitted_at,
        top_preferences: ranked.map do |obs|
          {
            item_name: obs.item_name,
            category: obs.item_category,
            rank: obs.rank,
            duration_seconds: obs.duration_seconds,
            frequency_count: obs.frequency_count
          }
        end
      }
    end

    def get_ablls_assessment
      # Check if SkillsAssessment model exists
      if defined?(SkillsAssessment)
        ablls = SkillsAssessment
          .joins(:assessment_cycle)
          .where(assessment_cycles: { student_id: student.id })
          .where(status: "submitted")
          .last

        if ablls
          return {
            available: true,
            completed_at: ablls.completed_at,
            scores: ablls.scores
          }
        end
      end

      { available: false, message: "ABLLS assessment data not found" }
    end

    def get_behavior_assessment
      # Get MASS and FAST assessments
      mass = MassAssessment
        .where(student_id: student.id)
        .where(status: "completed")
        .last

      fast = FastAssessment
        .where(student_id: student.id)
        .where(status: "completed")
        .last

      {
        available: mass.present? || fast.present?,
        mass: mass ? {
          scores: mass.function_scores,
          completed_at: mass.completed_at
        } : nil,
        fast: fast ? {
          risk_indicators: fast.risk_indicators,
          completed_at: fast.completed_at
        } : nil
      }
    end
  end
end
