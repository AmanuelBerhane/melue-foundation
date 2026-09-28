# app/services/students/goal_summary_service.rb
# frozen_string_literal: true

module Students
  class GoalSummaryService < ApplicationService
    attr_reader :student, :include_mastered

    def initialize(student, include_mastered: false)
      @student = student
      @include_mastered = include_mastered
    end

    def call
      return failure("Student not found") unless student

      success(build_summary)
    end

    private

    def build_summary
      # Get active IUP
      active_iup = student.active_iup

      # Get all student goals for counting
      all_goals = student.student_goals

      # Get student goals for this IUP (for station grouping)
      goals = student.student_goals.where(iup_id: active_iup&.id)
      goals = goals.where.not(status: "archived")

      # Filter mastered goals based on include_mastered
      if include_mastered
        # When include_mastered is true, include all goals except archived
        filtered_goals = goals
      else
        # When include_mastered is false, exclude mastered goals
        filtered_goals = goals.where.not(status: "mastered")
      end

      # Group by station
      stations_data = filtered_goals.includes(:goal, :therapy_station, goal: :goal_domain).group_by(&:therapy_station)

      {
        student_id: student.id,
        student_name: student.full_name,
        active_iup: active_iup ? {
          id: active_iup.id,
          status: active_iup.status
        } : nil,
        stations: stations_data.map do |station, station_goals|
          {
            station_id: station&.id,
            station_name: station&.name || "Unassigned",
            goals: station_goals.map do |sg|
              {
                id: sg.id,
                goal_id: sg.goal_id,
                goal_name: sg.goal&.name,
                goal_type: sg.goal&.goal_type,
                status: sg.status,
                progress_percent: sg.progress_percent.to_f,
                clinical_note: sg.clinical_note,
                # Add these for test compatibility
                name: sg.goal&.name,
                domain: sg.goal&.goal_domain&.name
              }
            end
          }
        end,
        total_goals: all_goals.count,
        active_goals: all_goals.where(status: "active").count,
        mastered_goals: all_goals.where(status: "mastered").count
      }
    end
  end
end
