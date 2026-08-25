# frozen_string_literal: true

module Trials
  # Core trial-logging service for standard and task_analysis goals (FR-095).
  # Consumed by TherapySessions::LogTrialService and reusable for the
  # Assessment Dashboard later.
  #
  # Business rules enforced (FR-093, FR-094, FR-095):
  #   - Session must be in_progress
  #   - Participant must belong to the session
  #   - StudentGoal must belong to the participant's student
  #   - PromptLevel must be active; its label is snapshotted at log time
  #   - Idempotent on client_event_id: a duplicate submission returns the
  #     existing trial instead of creating a second one (offline sync safety)
  #   - Trials are append-only; this service never updates an existing trial
  #   - Task-analysis goals require a student_goal_step that belongs to the
  #     goal; standard goals must not carry a step
  #   - Progress is recalculated after each successful trial log
  class LogTrial < ApplicationService
    # @param therapy_session [TherapySession]
    # @param participation_id [String] UUID of the SessionParticipant
    # @param student_goal_id [String] UUID of the StudentGoal
    # @param prompt_level_id [String] UUID of the PromptLevel
    # @param outcome [String] 'correct' | 'incorrect' | 'no_response'
    # @param client_event_id [String] client-assigned UUID for idempotency
    # @param logged_at [DateTime] client-recorded timestamp (supports offline)
    # @param student_goal_step_id [String, nil] UUID of StudentGoalStep (required for task_analysis)
    def initialize(therapy_session:, participation_id:, student_goal_id:,
                   prompt_level_id:, outcome:, client_event_id:, logged_at:,
                   student_goal_step_id: nil)
      @session              = therapy_session
      @participation_id     = participation_id
      @student_goal_id      = student_goal_id
      @prompt_level_id      = prompt_level_id
      @outcome              = outcome
      @client_event_id      = client_event_id
      @logged_at            = logged_at
      @student_goal_step_id = student_goal_step_id
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

      step = resolve_step(student_goal)
      return failure(@step_error) if @step_error

      trial = build_trial(participant, student_goal, prompt_level, step)
      return failure(trial.errors.full_messages.join(", ")) unless trial.save

      # Recalculate progress after successful trial log
      Trials::CalculateProgress.call(student_goal: student_goal)

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

    def resolve_step(student_goal)
      goal_type = student_goal.goal.goal_type

      if goal_type == "task_analysis"
        if @student_goal_step_id.blank?
          @step_error = "Step is required for task analysis goals"
          return nil
        end

        step = StudentGoalStep.find_by(id: @student_goal_step_id, student_goal_id: student_goal.id)
        unless step
          @step_error = "Step does not belong to this student goal"
          return nil
        end
        step
      else
        if @student_goal_step_id.present?
          @step_error = "Step must be blank for standard goals"
          return nil
        end
        nil
      end
    end

    def build_trial(participant, student_goal, prompt_level, step)
      Trial.new(
        therapy_session:       @session,
        session_participant:   participant,
        student_goal:          student_goal,
        student_goal_step:     step,
        prompt_level:          prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome:               @outcome,
        client_event_id:       @client_event_id,
        logged_at:             @logged_at
      )
    end
  end
end
