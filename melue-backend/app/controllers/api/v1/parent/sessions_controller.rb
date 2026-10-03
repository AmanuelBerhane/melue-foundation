# frozen_string_literal: true

module Api
  module V1
    module Parent
      # Finalised session history for a child. In-progress and draft sessions
      # are withheld — parents only see submitted or reviewed summaries.
      class SessionsController < BaseController
        before_action :guardian_student!

        # @oas_include
        # @summary Submitted/reviewed therapy sessions for a child
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter student_id(path) [!String] Student ID
        # @response Success (200) [Hash{ data: Array<Hash>, meta: Hash }]
        # @response Not Found (404) [Hash{ error: String }]
        # GET /api/v1/parent/students/:student_id/sessions
        def index
          scope = TherapySession.kept
                                .joins(:session_participants, :session_summary)
                                .where(session_participants: { student_id: @student.id })
                                .merge(SessionSummary.submitted_or_reviewed)
                                .includes(:teacher, :therapy_station, :therapy_room, :session_block_definition,
                                          :session_summary, trials: { student_goal: :goal })
                                .order(started_at: :desc)
          sessions, meta = paginated(scope)

          render json: { data: ParentSessionSerializer.new(sessions, student: @student).as_json, meta: meta }
        end
      end
    end
  end
end
