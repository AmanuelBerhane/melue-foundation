# frozen_string_literal: true

class TrialSerializer < ApplicationSerializer
  private

  def serialize(trial)
    {
      id: trial.id,
      session_participant_id: trial.session_participant_id,
      outcome: trial.outcome,
      prompt_label: trial.prompt_label_snapshot,
      prompt_label_snapshot: trial.prompt_label_snapshot,
      prompt_level_id: trial.prompt_level_id,
      student_goal_id: trial.student_goal_id,
      student_goal_step_id: trial.student_goal_step_id,
      client_event_id: trial.client_event_id,
      logged_at: trial.logged_at
    }
  end
end
