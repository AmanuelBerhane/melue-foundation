# app/services/charts/trial_distribution_service.rb
module Charts
  class TrialDistributionService < ApplicationService
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
        .includes(:prompt_level)

      data = {
        goal_id: student_goal.id,
        goal_name: student_goal.goal_name,
        student_name: student_goal.student.full_name,
        start_date: start_date.to_date,
        end_date: end_date.to_date,
        distribution: build_distribution(trials)
      }

      success(data)
    end

    private

    def build_distribution(trials)
      grouped = trials.group_by { |t| t.prompt_level&.label || "Unknown" }

      grouped.map do |label, prompt_trials|
        total = prompt_trials.count
        correct = prompt_trials.count { |t| t.outcome == "correct" }
        incorrect = prompt_trials.count { |t| t.outcome == "incorrect" }

        {
          prompt_label: label,
          total_trials: total,
          correct: correct,
          incorrect: incorrect,
          no_response: prompt_trials.count { |t| t.outcome == "no_response" }
        }
      end
    end
  end
end
