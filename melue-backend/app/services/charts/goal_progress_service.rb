# app/services/charts/goal_progress_service.rb
module Charts
  class GoalProgressService < ApplicationService
    attr_reader :student_goal, :start_date, :end_date

    def initialize(student_goal, start_date = nil, end_date = nil)
      @student_goal = student_goal
      @start_date = start_date || 30.days.ago
      @end_date = end_date || Time.current
    end

    def call
      return failure("Student goal not found") unless student_goal

      trials = student_goal.trials
        .where(logged_at: start_date..end_date)
        .order(logged_at: :asc)

      data = {
        goal_id: student_goal.id,
        goal_name: student_goal.goal_name,
        student_name: student_goal.student.full_name,
        start_date: start_date.to_date,
        end_date: end_date.to_date,
        data_points: build_data_points(trials)
      }

      success(data)
    end

    private

    def build_data_points(trials)
      grouped = trials.group_by { |t| t.logged_at.to_date }

      grouped.map do |date, day_trials|
        total = day_trials.count
        correct = day_trials.count { |t| t.outcome == "correct" }
        incorrect = day_trials.count { |t| t.outcome == "incorrect" }
        no_response = day_trials.count { |t| t.outcome == "no_response" }

        {
          date: date,
          total_trials: total,
          correct: correct,
          incorrect: incorrect,
          no_response: no_response,
          success_rate: total > 0 ? (correct.to_f / total * 100).round(2) : 0
        }
      end
    end
  end
end
