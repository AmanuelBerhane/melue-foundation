# app/serializers/assessments/dashboard_serializer.rb
module Assessments
  class DashboardSerializer
    def initialize(data)
      @data = data
    end

    def as_json(*)
      {
        summary: @data[:summary],
        students: @data[:students],
        assessment_period: @data[:assessment_period]
      }
    end
  end
end
