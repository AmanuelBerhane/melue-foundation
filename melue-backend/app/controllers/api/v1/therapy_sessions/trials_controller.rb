# frozen_string_literal: true

module Api::V1::TherapySessions
  # Handles trial logging within an active therapy session.
  class TrialsController < Api::V1::BaseController
    before_action :authenticate_user!
    before_action :set_session

    # POST /api/v1/therapy_sessions/:therapy_session_id/trials
    #
    # Logs a single trial. Idempotent on client_event_id (FR-093, FR-094).
    # Snapshots the prompt label at log time.
    #
    # @oas_include
    # @summary Log a trial
    # @tags Active Therapy
    # @auth [bearer_jwt]
    # @parameter therapy_session_id(path) [!String] Therapy session UUID
    # @request_body Trial data [!Hash{ participation_id: String, student_goal_id: String, prompt_level_id: String, outcome: String, client_event_id: String, logged_at: String }]
    # @response Trial logged (201) [Hash{ trial: Hash }]
    # @response Duplicate submission (200) [Hash{ trial: Hash }]
    # @response Validation error (422) [Hash{ message: String }]
    def create
      result = TherapySessions::LogTrialService.call(
        session: @session,
        participation_id: params[:participation_id],
        student_goal_id: params[:student_goal_id],
        prompt_level_id: params[:prompt_level_id],
        outcome: params[:outcome],
        client_event_id: params[:client_event_id],
        logged_at: params[:logged_at] || Time.current
      )

      if result.success?
        status = Trial.exists?(client_event_id: params[:client_event_id]) ? :ok : :created
        render json: { trial: trial_payload(result.data) }, status: status
      else
        render json: { message: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/v1/therapy_sessions/:therapy_session_id/participants/:participant_id/trial_stream
    #
    # Returns the last N trials for a specific participant and optional goal (FR-093).
    #
    # @oas_include
    # @summary Get recent trial stream for a participant
    # @tags Active Therapy
    # @auth [bearer_jwt]
    # @parameter therapy_session_id(path) [!String] Therapy session UUID
    # @parameter participant_id(query) [!String] SessionParticipant UUID
    # @parameter student_goal_id(query) [String] Optional StudentGoal UUID to filter by
    # @parameter limit(query) [Integer] Max trials to return. default: (10) maximum: (50)
    # @response Trial stream (200) [Array<Hash>]
    def stream
      participant = @session.session_participants.find_by(id: params[:participant_id])
      return render json: { message: "Participant not found" }, status: :not_found unless participant

      limit = [ params[:limit].to_i, 50 ].min
      limit = 10 if limit <= 0

      trials = participant.recent_trials(
        student_goal_id: params[:student_goal_id],
        limit: limit
      )

      render json: { trials: trials.map { |t| trial_payload(t) } }
    end

    private

    def set_session
      @session = TherapySession.find_by(id: params[:therapy_session_id])
      render json: { message: "Session not found" }, status: :not_found unless @session
    end

    def trial_payload(trial)
      {
        id: trial.id,
        outcome: trial.outcome,
        prompt_label: trial.prompt_label_snapshot,
        prompt_level_id: trial.prompt_level_id,
        logged_at: trial.logged_at,
        client_event_id: trial.client_event_id,
        student_goal_id: trial.student_goal_id
      }
    end
  end
end
