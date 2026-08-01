# frozen_string_literal: true

module TherapySessions
  # Logs a single trial against a session participant and goal.
  #
  # Business rules enforced (FR-093, FR-094):
  #   - Session must be in_progress
  #   - Participant must belong to the session
  #   - StudentGoal must belong to the participant's student
  #   - PromptLevel must be active
  #   - prompt_label_snapshot is captured from the PromptLevel at log time,
  #     preserving the label even if configuration changes later (FR-094)
  #   - Idempotent on client_event_id: a duplicate submission returns the
  #     existing trial rather than creating a second one (offline sync safety)
  #   - Trials are append-only; this service never updates an existing trial
  class LogTrialService < ApplicationService
    # @param session [TherapySession]
    # @param participation_id [String] UUID of the SessionParticipant
    # @param student_goal_id [String] UUID of the StudentGoal
    # @param prompt_level_id [String] UUID of the PromptLevel
    # @param outcome [String] 'correct' | 'incorrect' | 'no_response'
    # @param client_event_id [String] client-assigned UUID for idempotency
    # @param logged_at [DateTime] client-recorded timestamp (supports offline)
    def initialize(session:, participation_id:, student_goal_id:, prompt_level_id:, outcome:, client_event_id:, logged_at:)
      @session          = session
      @participation_id = participation_id
      @student_goal_id  = student_goal_id
      @prompt_level_id  = prompt_level_id
      @outcome          = outcome
      @client_event_id  = client_event_id
      @logged_at        = logged_at
    end

    def call
      # Idempotency: return existing trial if client_event_id already recorded
      existing = Trial.find_by(client_event_id: @client_event_id)
      return success(existing) if existing

      return failure("Session is not in progress") unless @session.status_in_progress?

      participant = find_participant
      return failure("Participant not found in this session") unless participant

      student_goal = find_student_goal(participant)
      return failure("Goal does not belong to this participant's student") unless student_goal

      prompt_level = find_prompt_level
      return failure("Prompt level not found or inactive") unless prompt_level

      trial = build_trial(participant, student_goal, prompt_level)
      return failure(trial.errors.full_messages.join(", ")) unless trial.save

      success(trial)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end

    private

    def find_participant
      @session.session_participants.find_by(id: @participation_id)
    end

    def find_student_goal(participant)
      StudentGoal.find_by(id: @student_goal_id, student_id: participant.student_id)
    end

    def find_prompt_level
      PromptLevel.find_by(id: @prompt_level_id, is_active: true)
    end

    def build_trial(participant, student_goal, prompt_level)
      Trial.new(
        therapy_session:       @session,
        session_participant:   participant,
        student_goal:          student_goal,
        prompt_level:          prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome:               @outcome,
        client_event_id:       @client_event_id,
        logged_at:             @logged_at
      )
    end
  end
end
