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
    # @request_body_ref #/components/requestBodies/LogTrial
    # @response_ref (201) #/components/responses/TrialLogged
    # @response_ref (200) #/components/responses/TrialLogged
    # @response_ref (422) #/components/responses/Error
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
        status_code = result.data.previously_new_record? ? :created : :ok
        render json: { trial: TrialSerializer.new(result.data).as_json }, status: status_code
      else
        render_error(result.error, :unprocessable_entity)
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
    # @parameter_ref #/components/parameters/ParticipantIdQuery
    # @parameter_ref #/components/parameters/StudentGoalIdQuery
    # @parameter_ref #/components/parameters/TrialStreamLimit
    # @response_ref (200) #/components/responses/TrialStream
    # @response_ref (404) #/components/responses/Error
    def stream
      participant = @session.session_participants.find_by(id: params[:participant_id])
      return render_error("Participant not found", :not_found) unless participant

      limit = [params[:limit].to_i, 50].min
      limit = 10 if limit <= 0

      trials = participant.recent_trials(
        student_goal_id: params[:student_goal_id],
        limit: limit
      )

      render json: { trials: TrialSerializer.new(trials).as_json }
    end

    private

    def set_session
      @session = TherapySession.find_by(id: params[:therapy_session_id])
      render_error("Session not found", :not_found) unless @session
    end
  end
end
