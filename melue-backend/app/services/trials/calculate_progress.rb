# frozen_string_literal: true

module Trials
  # Pure progress calculator for both standard and task_analysis goals (FR-095).
  # Reusable — will also be consumed by the Assessment Dashboard.
  #
  # "Independent" trial = outcome is 'correct' AND prompt level label is '+'
  # (the highest prompt level = fully independent).
  class CalculateProgress < ApplicationService
    def initialize(student_goal:)
      @student_goal = student_goal
    end

    def call
      if @student_goal.goal.goal_type == "task_analysis"
        calculate_task_analysis
      else
        calculate_standard
      end
    end

    private

    # Standard goals: independence % = independent_trials / total_trials
    def calculate_standard
      trials = Trial.where(student_goal: @student_goal)
      total = trials.count
      independent = independent_trial_count(trials)

      percent = total.zero? ? 0.0 : ((independent.to_f / total) * 100).round(2)

      @student_goal.update!(progress_percent: percent)

      success(
        mode: "standard",
        total_trials: total,
        independent_trials: independent,
        independence_percent: percent
      )
    end

    # Task analysis goals: per-step independence, overall = % steps mastered
    def calculate_task_analysis
      steps = @student_goal.student_goal_steps.ordered

      step_stats = steps.map do |step|
        step_trials = Trial.where(student_goal_step: step)
        total = step_trials.count
        independent = independent_trial_count(step_trials)

        percent = total.zero? ? 0.0 : ((independent.to_f / total) * 100).round(2)
        new_status = determine_step_status(percent, total)

        step.update!(
          independence_percent: percent,
          status: new_status
        )

        {
          id: step.id,
          step_number: step.step_number,
          name: step.name,
          total_trials: total,
          independent_trials: independent,
          independence_percent: percent,
          status: new_status
        }
      end

      mastered_count = step_stats.count { |s| s[:status] == "mastered" }
      total_steps = step_stats.size
      overall_percent = total_steps.zero? ? 0.0 : ((mastered_count.to_f / total_steps) * 100).round(2)
      goal_mastered = mastered_count == total_steps && total_steps.positive?

      @student_goal.update!(
        progress_percent: overall_percent,
        status: goal_mastered ? "mastered" : "in_progress"
      )

      success(
        mode: "task_analysis",
        steps: step_stats,
        total_steps: total_steps,
        mastered_steps_count: mastered_count,
        steps_mastered_percent: overall_percent,
        goal_mastered: goal_mastered
      )
    end

    # An "independent" trial: outcome=correct AND prompt level label='+'
    def independent_trial_count(scope)
      scope.joins(:prompt_level)
           .where(outcome: "correct", prompt_levels: { label: "+" })
           .count
    end

    def determine_step_status(percent, total)
      return "not_started" if total.zero?
      return "mastered" if percent >= 80.0
      "in_progress"
    end
  end
end
