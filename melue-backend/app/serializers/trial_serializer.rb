# frozen_string_literal: true

class TrialSerializer < ApplicationSerializer
  private

  def serialize(trial)
    {
      id: trial.id,
      outcome: trial.outcome,
      prompt_label: trial.prompt_label_snapshot,
      prompt_level_id: trial.prompt_level_id,
      student_goal_id: trial.student_goal_id,
      student_goal_step_id: trial.student_goal_step_id,
      client_event_id: trial.client_event_id,
      logged_at: trial.logged_at
    }
  end
end
