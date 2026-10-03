# frozen_string_literal: true

class HomeObservationSerializer < ApplicationSerializer
  private

  def serialize(observation)
    {
      id: observation.id,
      student_id: observation.student_id,
      guardian_id: observation.guardian_id,
      content: observation.content,
      observed_on: observation.observed_on.iso8601,
      submitted_at: observation.submitted_at.iso8601
    }
  end
end
