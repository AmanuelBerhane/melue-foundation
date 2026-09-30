# frozen_string_literal: true

module Api
  module V1
    module TherapyCoordinator
      class StaffAvailabilitiesController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_coordinator
        before_action :set_availability, only: [ :destroy ]

        # @oas_include
        # @summary List staff unavailabilities
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @parameter teacher_id(query) [String] Filter by teacher UUID
        # @parameter date(query) [String] Filter by date (YYYY-MM-DD)
        # @parameter start_date(query) [String] Filter by start date (YYYY-MM-DD)
        # @parameter end_date(query) [String] Filter by end date (YYYY-MM-DD)
        # @response (200) Array<Hash>
        # @response (403) Hash{ error: String }
        def index
          scope = StaffAvailability.includes(:staff_member, :session_block_definition).order(unavailable_date: :desc)

          if params[:teacher_id].present? || params[:staff_member_id].present?
            scope = scope.where(staff_member_id: params[:teacher_id] || params[:staff_member_id])
          end

          if params[:date].present?
            scope = scope.where(unavailable_date: params[:date])
          end

          if params[:start_date].present? && params[:end_date].present?
            scope = scope.where(unavailable_date: params[:start_date]..params[:end_date])
          end

          render json: scope.map { |a| serialize_availability(a) }, status: :ok
        end

        # @oas_include
        # @summary Mark a teacher as unavailable (FR-122)
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @request_body Unavailability payload [Hash{ teacher_id: String, unavailable_date: String, session_block_definition_id: String, reason: String }]
        # @response (201) Hash{ availability: Hash, impacted_assignments_count: Integer, impacted_assignments: Array }
        # @response (422) Hash{ error: String }
        # @response (403) Hash{ error: String }
        def create
          result = ::TherapyCoordinator::MarkTeacherUnavailableService.call(availability_params, current_user)

          if result.success?
            render json: {
              availability: serialize_availability(result.data[:availability]),
              impacted_assignments_count: result.data[:impacted_assignments_count],
              impacted_assignments: result.data[:impacted_assignments].map { |a| serialize_assignment(a) }
            }, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # @oas_include
        # @summary Remove a staff unavailability record
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @parameter id(path) [!String] Unavailability UUID
        # @response (200) Hash{ message: String }
        # @response (404) Hash{ error: String }
        # @response (403) Hash{ error: String }
        def destroy
          @availability.destroy!
          render json: { message: "Unavailability record removed successfully" }, status: :ok
        end

        private

        def set_availability
          @availability = StaffAvailability.find_by(id: params[:id])
          render json: { error: "Unavailability record not found" }, status: :not_found and return unless @availability
        end

        def availability_params
          params.permit(
            :teacher_id,
            :staff_member_id,
            :unavailable_date,
            :date,
            :session_block_definition_id,
            :reason
          ).to_h
        end

        def serialize_availability(availability)
          {
            id: availability.id,
            teacher_id: availability.staff_member_id,
            teacher_name: availability.staff_member&.full_name,
            unavailable_date: availability.unavailable_date,
            session_block_definition_id: availability.session_block_definition_id,
            session_block_name: availability.session_block_definition&.name,
            full_day: availability.full_day?,
            reason: availability.reason,
            created_at: availability.created_at
          }
        end

        def serialize_assignment(assignment)
          {
            id: assignment.id,
            student_id: assignment.student_id,
            student_name: assignment.student&.full_name,
            session_block_definition_id: assignment.session_block_definition_id,
            session_block_name: assignment.session_block_definition&.name,
            scheduled_date: assignment.scheduled_date,
            status: assignment.status
          }
        end
      end
    end
  end
end
