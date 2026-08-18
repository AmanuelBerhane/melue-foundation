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

      # Get behavior incidents for the student
      incidents = BehaviorIncident
        .for_student(student.id)
        .for_date_range(start_date, end_date)
        .order(occurred_at: :asc)

      data = {
        student_id: student.id,
        student_name: student.full_name,
        start_date: start_date.to_date,
        end_date: end_date.to_date,
        data_points: build_data_points(incidents)
      }

      success(data)
    end

    private

    def build_data_points(incidents)
      return [] if incidents.empty?

      grouped = incidents.group_by { |i| i.occurred_at.to_date }

      grouped.map do |date, day_incidents|
        {
          date: date,
          total_incidents: day_incidents.count,
          by_category: day_incidents.group_by(&:category).map do |category, category_incidents|
            { category: category, count: category_incidents.count }
          end,
          by_intensity: day_incidents.group_by(&:intensity).map do |intensity, intensity_incidents|
            { intensity: intensity, count: intensity_incidents.count }
          end
        }
      end
    end
  end
end
