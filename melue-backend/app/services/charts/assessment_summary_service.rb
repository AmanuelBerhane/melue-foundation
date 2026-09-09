# app/services/charts/assessment_summary_service.rb
module Charts
  class AssessmentSummaryService < ApplicationService
    attr_reader :student

    def initialize(student)
      @student = student
    end

    def call
      return failure("Student not found") unless student

      # Get preference assessment data
      preference_data = get_preference_assessment

      # TODO: Add ABLLS and MASS/FAST data when implemented
      data = {
        student_id: student.id,
        student_name: student.full_name,
        assessments: {
          preference: preference_data,
          skills: { available: false, message: "ABLLS assessment data will be available when implemented" },
          behavior: { available: false, message: "MASS/FAST assessment data will be available when implemented" }
        }
      }

      success(data)
    end

    private

    def get_preference_assessment
      # Find the latest assessment cycle with preference assessment
      assessment_cycle = student.assessment_cycles
        .includes(:preference_assessment)
        .where(preference_assessments: { status: "submitted" })
        .last

      return { available: false, message: "No submitted preference assessment found" } unless assessment_cycle

      preference = assessment_cycle.preference_assessment

      # Get ranked observations
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
  end
end
