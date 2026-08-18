module Reports
  class FoundationOverviewService < ApplicationService
    def initialize(start_date: Time.current.beginning_of_month, end_date: Time.current.end_of_month)
      @start_date = start_date
      @end_date = end_date
    end

    def call
      success({
        total_active_students: total_active_students,
        goals_mastered_this_month: goals_mastered_in_range,
        behavior_incident_trends: behavior_incident_trends,
        teacher_performance: teacher_performance,
        program_distribution: program_distribution
      })
    rescue StandardError => e
      failure(e.message)
    end

    private

    def total_active_students
      # Exclude statuses that mean the student is no longer active
      Student.where.not(status: [ "discharged", "inactive", "archived" ]).count
    end

    def goals_mastered_in_range
      # Goals that reached "mastered" status within the current date range
      StudentGoal.where(status: "mastered", updated_at: @start_date..@end_date).count
    end

    def behavior_incident_trends
      # TODO: Behavior incidents are not fully modeled yet (ABC data).
      # Placeholder for future implementation.
      []
    end

    def teacher_performance
      # TODO: Placeholder for teacher performance metrics (e.g., sessions completed, trials logged).
      []
    end

    def program_distribution
      # Group students by their program type (e.g., Regular, Pulled Out)
      Student.where.not(status: [ "discharged", "inactive", "archived" ])
             .group(:program_type)
             .count
    end
  end
end
