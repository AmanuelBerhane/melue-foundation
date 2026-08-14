# frozen_string_literal: true

class PreferenceAssessmentSerializer < ApplicationSerializer
  private

  def serialize(assessment)
    {
      id:                  assessment.id,
      assessment_cycle_id: assessment.assessment_cycle_id,
      student_id:          assessment.student_id,
      status:              assessment.status,
      submitted_at:        assessment.submitted_at,
      contexts:            PreferenceAssessment::CONTEXTS,
      observations:        PreferenceObservationSerializer.new(
                             assessment.ranked_observations.to_a
                           ).as_json
    }
  end
end
