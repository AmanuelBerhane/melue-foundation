# frozen_string_literal: true

module ProgramDirector
  # FR-052: SCR-PD-001 — Program Director Dashboard statistics.
  # Returns:
  #   - students_in_assessment: count of students currently in assessment
  #   - assessment_complete: count of students with assessment complete / ready for IUP
  #   - active_iup_plans: count of active IUPs
  #   - goals_assigned_this_month: count of student goals assigned in the current calendar month
  class DashboardService < ApplicationService
    def call
      now = Time.current
      start_of_month = now.beginning_of_month
      end_of_month = now.end_of_month

      students_in_assessment = Student.kept.where(status: "in_assessment").count
      assessment_complete = Student.kept.where(status: %w[assessment_complete ready_for_iup]).count
      active_iup_plans = Iup.kept.where(status: "active").count
      goals_assigned_this_month = StudentGoal.kept.where(created_at: start_of_month..end_of_month).count

      success({
        students_in_assessment: students_in_assessment,
        assessment_complete: assessment_complete,
        active_iup_plans: active_iup_plans,
        goals_assigned_this_month: goals_assigned_this_month
      })
    end
  end
end
