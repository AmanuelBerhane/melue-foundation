# frozen_string_literal: true

module Api
  module V1
    module TherapyCoordinator
      class SessionSummariesController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_coordinator
        before_action :set_summary, only: [ :review ]

        # GET /api/v1/therapy_coordinator/session_summaries
        #
        # Returns submitted and reviewed session summaries for coordinator review.
        #
        # @oas_include
        # @summary List session summaries for coordinator review
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @parameter status(query) [String] Filter by summary status (draft, submitted, reviewed)
        # @parameter date_from(query) [DateTime] Filter summaries submitted after this date
        # @parameter date_to(query) [DateTime] Filter summaries submitted before this date
        # @parameter teacher_id(query) [String] Filter by teacher UUID
        # @parameter station_id(query) [String] Filter by station UUID
        # @parameter room_id(query) [String] Filter by room UUID
        # @parameter student_id(query) [String] Filter by student UUID
        # @parameter sort_by(query) [String] Field to sort by (submitted_at, status, teacher, station)
        # @parameter sort_order(query) [String] Sort order (asc, desc)
        # @response (200) Hash{ session_summaries: Array<Hash> }
        # @response (403) Hash{ error: String }
        def index
          scope = SessionSummary.includes(
            therapy_session: [
              :teacher,
              :therapy_station,
              :therapy_room,
              :session_block_definition,
              session_participants: :student
            ]
          )

          # Status filter: default to submitted & reviewed (exclude drafts unless requested)
          if params[:status].present?
            scope = scope.where(status: params[:status])
          else
            scope = scope.where(status: %w[submitted reviewed])
          end

          # Date range filters
          scope = scope.where("session_summaries.submitted_at >= ?", params[:date_from]) if params[:date_from].present?
          scope = scope.where("session_summaries.submitted_at <= ?", params[:date_to]) if params[:date_to].present?

          # Relational filters
          scope = scope.joins(:therapy_session).where(therapy_sessions: { teacher_id: params[:teacher_id] }) if params[:teacher_id].present?
          scope = scope.joins(:therapy_session).where(therapy_sessions: { therapy_station_id: params[:station_id] }) if params[:station_id].present?
          scope = scope.joins(:therapy_session).where(therapy_sessions: { therapy_room_id: params[:room_id] }) if params[:room_id].present?

          if params[:student_id].present?
            scope = scope.joins(therapy_session: :session_participants)
                         .where(session_participants: { student_id: params[:student_id] })
                         .distinct
          end

          # Sorting
          order_direction = params[:sort_order].to_s.casecmp("asc").zero? ? :asc : :desc

          scope = case params[:sort_by]
          when "status"
                    scope.order(status: order_direction)
          when "submitted_at"
                    scope.order(submitted_at: order_direction)
          when "teacher"
                    scope.joins(therapy_session: :teacher).order(Arel.sql("staff_members.full_name") => order_direction)
          when "station"
                    scope.joins(therapy_session: :therapy_station).order(Arel.sql("therapy_stations.name") => order_direction)
          else
                    scope.order(submitted_at: :desc, created_at: :desc)
          end

          summaries_payload = scope.map do |summary|
            session = summary.therapy_session
            {
              id: summary.id,
              status: summary.status,
              qualitative_notes: summary.qualitative_notes,
              submitted_at: summary.submitted_at,
              reviewed_at: summary.reviewed_at,
              reviewed_by_user_id: summary.reviewed_by_user_id,
              session: {
                id: session.id,
                status: session.status,
                teacher: { id: session.teacher_id, name: session.teacher.full_name },
                station: { id: session.therapy_station_id, name: session.therapy_station.name },
                room: { id: session.therapy_room_id, name: session.therapy_room.name },
                block: { id: session.session_block_definition_id, name: session.session_block_definition.name },
                students: session.session_participants.map do |p|
                  { id: p.student.id, name: p.student.full_name }
                end
              }
            }
          end

          render json: { session_summaries: summaries_payload }, status: :ok
        end

        # PATCH /api/v1/therapy_coordinator/session_summaries/:id/review
        #
        # Marks a submitted session summary as reviewed.
        #
        # @oas_include
        # @summary Review a submitted session summary
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (200) Hash{ session_summary: Hash }
        # @response (403) Hash{ error: String }
        # @response (422) Hash{ error: String }
        def review
          result = ::SessionSummaries::ReviewService.call(
            summary: @summary,
            reviewed_by_user: current_user
          )

          if result.success?
            summary = result.data
            payload = {
              id: summary.id,
              status: summary.status,
              qualitative_notes: summary.qualitative_notes,
              submitted_at: summary.submitted_at,
              reviewed_at: summary.reviewed_at,
              reviewed_by_user_id: summary.reviewed_by_user_id
            }
            render json: { session_summary: payload }, status: :ok
          else
            render_error(result.error, :unprocessable_entity)
          end
        end

        private

        def set_summary
          @summary = SessionSummary.find_by(id: params[:id])
          render_not_found("Session summary not found") unless @summary
        end
      end
    end
  end
end
