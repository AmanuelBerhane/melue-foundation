# frozen_string_literal: true

# Serializes Student records for API responses.
# Supports two modes:
#   - List mode (default): compact representation for index endpoints
#   - Profile mode: full representation including guardian info and goals
class StudentSerializer < ApplicationSerializer
  def initialize(resource, profile: false)
    super(resource)
    @profile = profile
  end

  private

  def serialize(student)
    payload = {
      id: student.id,
      full_name: student.full_name,
      first_name: student.first_name,
      middle_name: student.middle_name,
      last_name: student.last_name,
      date_of_birth: student.date_of_birth,
      age: student.age,
      program_type: student.program_type,
      therapy_group: student.therapy_group,
      status: student.status,
      headshot_url: headshot_url(student)
    }

    if @profile
      payload.merge!(
        diagnosis: student.diagnosis,
        guardian_name: student.guardian_name,
        guardian_phone: student.guardian_phone,
        current_goals_summary: student.current_goals_summary
      )
    end

    payload
  end

  def headshot_url(student)
    return nil unless student.headshot.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      student.headshot,
      only_path: true
    )
  end
end
