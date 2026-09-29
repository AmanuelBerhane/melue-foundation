# frozen_string_literal: true

module Assessments
  class DashboardSerializer
    def initialize(payload)
      @payload = payload
    end

    def as_json(*)
      {
        summary: @payload[:summary],
        assessment_period: @payload[:assessment_period],
        students: @payload[:students]
      }
    end
  end
end
