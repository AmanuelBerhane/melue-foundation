# frozen_string_literal: true

module Api
  module V1
    module TherapySessions
      # Handles behavior incident recording within an active therapy session (FR-097, FR-098, FR-099).
      class BehaviorIncidentsController < Api::V1::BaseController
        include TeacherSessionScoped

        before_action :authenticate_user!
        before_action :require_staff_member!
        before_action :set_session
        before_action :authorize_teacher_session!

        # GET /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents
        #
        # Lists all behavior incidents recorded for this session.
        #
        # @oas_include
        # @summary List behavior incidents for a therapy session
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (200) Array<Hash>
        # @response (404) Hash{ error: String }
        def index
          incidents = @session.behavior_incidents.includes(:student, :staff_member, student_goal: :goal).order(occurred_at: :asc)
          render json: BehaviorIncidentSerializer.new(incidents).as_json, status: :ok
        end

        # POST /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents
        #
        # Records an incident linked to session, student, active goal, and teacher.
        #
        # @oas_include
        # @summary Record a behavior incident in a session
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (201) Hash
        # @response (422) Hash{ error: String }
        def create
          result = ::TherapySessions::RecordBehaviorIncidentService.call(
            session: @session,
            student_id: params[:student_id],
            student_goal_id: params[:student_goal_id],
            staff_member: current_staff_member,
            incident_params: incident_params
          )

          if result.success?
            render json: BehaviorIncidentSerializer.new(result.data).as_json, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # GET /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents/options
        #
        # Returns configurable dropdown options for the Behavior Incident Modal (SCR-003)
        # pre-populated with active session context.
        #
        # @oas_include
        # @summary Get modal dropdown options with session context
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (200) Hash
        def options
          active_p = @session.active_participant
          secondary_p = @session.secondary_participant

          context = {
            session_id: @session.id,
            room: @session.therapy_room&.name,
            station: @session.therapy_station&.name,
            teacher: {
              id: current_staff_member.id,
              name: current_staff_member.full_name
            },
            current_date: Date.current.to_s,
            current_time: Time.current.strftime("%H:%M"),
            active_participant: active_p ? format_participant(active_p) : nil,
            secondary_participant: secondary_p ? format_participant(secondary_p) : nil
          }

          render json: BehaviorIncident.modal_options.merge(context: context), status: :ok
        end

        private

        def incident_params
          params.permit(
            :behavior_name, :behavior_definition, :frequency, :intensity,
            :category, :antecedent, :consequence, :location,
            :occurred_at, :additional_notes
          )
        end

        def format_participant(participant)
          focus_goal = if participant.current_focus_student_goal_id.present?
            StudentGoal.find_by(id: participant.current_focus_student_goal_id)
          else
            participant.student.student_goals.where(
              therapy_station_id: @session.therapy_station_id,
              status: %w[active in_progress]
            ).order(updated_at: :desc).first
          end

          {
            participant_id: participant.id,
            card_position: participant.card_position,
            student_id: participant.student_id,
            student_name: participant.student.full_name,
            active_goal: focus_goal ? { id: focus_goal.id, name: focus_goal.goal_name } : nil
          }
        end
      end
    end
  end
end
