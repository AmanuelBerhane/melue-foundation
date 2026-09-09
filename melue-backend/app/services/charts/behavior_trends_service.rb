# app/services/charts/behavior_trends_service.rb
module Charts
  class BehaviorTrendsService < ApplicationService
    attr_reader :student, :start_date, :end_date

    def initialize(student, start_date = nil, end_date = nil)
      @student = student
      @start_date = start_date || 30.days.ago
      @end_date = end_date || Time.current
    end

    def call
      return failure("Student not found") unless student

      # TODO: Replace with real behavior incident model when implemented
      # For now, return empty data structure
      data = {
        student_id: student.id,
        student_name: student.full_name,
        start_date: start_date.to_date,
        end_date: end_date.to_date,
        message: "Behavior incident data will be available when the ABC tracking module is implemented",
        data_points: []
      }

      success(data)
    end
  end
end
