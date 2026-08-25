# frozen_string_literal: true

module TherapySessions
  # Logs a single trial against a session participant and goal (FR-093–FR-095).
  #
  # Thin HTTP-facing wrapper that preserves the existing endpoint signature
  # and delegates the actual work to Trials::LogTrial, which recalculates
  # progress via Trials::CalculateProgress.
  #
  # Business rules enforced in Trials::LogTrial:
  #   - Session must be in_progress
  #   - Participant must belong to the session
  #   - StudentGoal must belong to the participant's student
  #   - PromptLevel must be active; its label is snapshotted at log time
  #   - Idempotent on client_event_id (offline sync safety)
  #   - Trials are append-only
  #   - Task-analysis goals require a student_goal_step; standard goals must
  #     not carry one
  class LogTrialService < ApplicationService
    # @param session [TherapySession]
    # @param participation_id [String] UUID of the SessionParticipant
    # @param student_goal_id [String] UUID of the StudentGoal
    # @param prompt_level_id [String] UUID of the PromptLevel
    # @param outcome [String] 'correct' | 'incorrect' | 'no_response'
    # @param client_event_id [String] client-assigned UUID for idempotency
    # @param logged_at [DateTime] client-recorded timestamp (supports offline)
    # @param student_goal_step_id [String, nil] UUID of StudentGoalStep (required for task_analysis)
    def initialize(session:, participation_id:, student_goal_id:, prompt_level_id:,
                   outcome:, client_event_id:, logged_at:, student_goal_step_id: nil)
      @session               = session
      @participation_id      = participation_id
      @student_goal_id       = student_goal_id
      @prompt_level_id       = prompt_level_id
      @outcome               = outcome
      @client_event_id       = client_event_id
      @logged_at             = logged_at
      @student_goal_step_id  = student_goal_step_id
    end

    def call
      Trials::LogTrial.call(
        therapy_session:      @session,
        participation_id:     @participation_id,
        student_goal_id:      @student_goal_id,
        prompt_level_id:      @prompt_level_id,
        outcome:              @outcome,
        client_event_id:      @client_event_id,
        logged_at:            @logged_at,
        student_goal_step_id: @student_goal_step_id
      )
    end
  end
end
