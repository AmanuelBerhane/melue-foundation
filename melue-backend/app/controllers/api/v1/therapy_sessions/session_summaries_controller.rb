# frozen_string_literal: true

module Api
  module V1
    module TherapySessions
      class SessionSummariesController < Api::V1::BaseController
        include TeacherSessionScoped

        before_action :authenticate_user!
        before_action :require_staff_member!
        before_action :set_session
        before_action :authorize_teacher_session!

        # GET /api/v1/therapy_sessions/:therapy_session_id/summary
        #
        # Returns the derived session summary payload including block info,
        # student performance metrics, prompt breakdowns, and notes.
        #
        # @oas_include
        # @summary Get session summary
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (200) Hash{ summary: Hash, session: Hash, participants: Array<Hash>, behavior_incidents: Array }
        # @response (403) Hash{ error: String }
        # @response (404) Hash{ error: String }
        def show
          result = ::SessionSummaries::BuildPayloadService.call(session: @session)

          if result.success?
            render json: result.data
          else
            render_error(result.error, :unprocessable_entity)
          end
        end

        # PATCH /api/v1/therapy_sessions/:therapy_session_id/summary/draft
        #
        # Saves qualitative notes as a draft without ending or modifying the session.
        #
        # @oas_include
        # @summary Save draft qualitative notes
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @request_body Hash{ qualitative_notes: String }
        # @response (200) Hash{ summary: Hash }
        # @response (422) Hash{ error: String }
        def draft
          result = ::SessionSummaries::SaveDraftService.call(
            session: @session,
            qualitative_notes: summary_params[:qualitative_notes]
          )

          if result.success?
            render json: { summary: result.data }, status: :ok
          else
            render_error(result.error, :unprocessable_entity)
          end
        end

        # POST /api/v1/therapy_sessions/:therapy_session_id/summary/submit
        #
        # Submits the summary report to the coordinator and marks the session completed.
        #
        # @oas_include
        # @summary Submit session summary and complete session
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @request_body Hash{ qualitative_notes: String }
        # @response (200) Hash{ summary: Hash }
        # @response (422) Hash{ error: String }
        def submit
          result = ::SessionSummaries::SubmitService.call(
            session: @session,
            qualitative_notes: summary_params[:qualitative_notes]
          )

          if result.success?
            render json: { summary: result.data }, status: :ok
          else
            render_error(result.error, :unprocessable_entity)
          end
        end

        # POST /api/v1/therapy_sessions/:therapy_session_id/summary/preview_pdf
        #
        # Previews the summary as a PDF document.
        #
        # @oas_include
        # @summary Preview session summary PDF
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (501) Hash{ error: String }
        def preview_pdf
          result = ::SessionSummaries::PreviewPdfService.call(session: @session)

          if result.success?
            send_data result.data, type: "application/pdf", disposition: "inline"
          else
            render json: { error: result.error }, status: :not_implemented
          end
        end

        private

        def summary_params
          params.permit(:qualitative_notes)
        end
      end
    end
  end
end
