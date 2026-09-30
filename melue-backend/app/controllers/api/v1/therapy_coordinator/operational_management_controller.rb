# frozen_string_literal: true

module Api
  module V1
    module TherapyCoordinator
      class OperationalManagementController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_coordinator

        # @oas_include
        # @summary Operational Management Screen data (SCR-TC-005)
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @parameter date(query) [String] Date for schedule overview (YYYY-MM-DD)
        # @parameter current_time(query) [String] Current time for block evaluation
        # @response (200) Hash{ date: String, summary: Hash, blocks: Array, teachers: Array, unassigned_alerts: Array }
        # @response (403) Hash{ error: String }
        def index
          result = ::TherapyCoordinator::OperationalOverviewService.call(params, current_user)

          if result.success?
            render json: result.data, status: :ok
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # @oas_include
        # @summary Reassign students to an available teacher (FR-123)
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @request_body Reassignment payload [Hash{ assignments: Array, assignment_id: String, new_teacher_id: String }]
        # @response (200) Hash{ reassigned_count: Integer, reassigned_assignments: Array }
        # @response (422) Hash{ error: String }
        # @response (403) Hash{ error: String }
        def reassign
          result = ::TherapyCoordinator::ReassignStudentsService.call(reassign_params, current_user)

          if result.success?
            render json: result.data, status: :ok
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # @oas_include
        # @summary Teacher performance metrics (FR-124)
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @parameter teacher_id(query) [String] Specific teacher UUID
        # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
        # @parameter end_date(query) [String] End date (YYYY-MM-DD)
        # @response (200) Array<Hash> | Hash
        # @response (403) Hash{ error: String }
        def performance_metrics
          result = ::TherapyCoordinator::TeacherPerformanceMetricsService.call(params, current_user)

          if result.success?
            render json: result.data, status: :ok
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # @oas_include
        # @summary Unassigned student warnings for current/upcoming blocks (FR-125)
        # @tags Therapy Coordinator
        # @auth [bearer_jwt]
        # @parameter date(query) [String] Target date (YYYY-MM-DD)
        # @parameter session_block_definition_id(query) [String] Block UUID
        # @parameter current_time(query) [String] Time string
        # @response (200) Hash{ target_date: String, alerts: Array, current_block: Hash, upcoming_block: Hash, total_unassigned_count: Integer }
        # @response (403) Hash{ error: String }
        def unassigned_alerts
          result = ::TherapyCoordinator::UnassignedStudentsAlertService.call(params, current_user)

          if result.success?
            render json: result.data, status: :ok
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        private

        def reassign_params
          params.permit(
            :assignment_id,
            :new_teacher_id,
            :target_teacher_id,
            :therapy_station_id,
            :therapy_room_id,
            assignment_ids: [],
            assignments: [ :assignment_id, :id, :new_teacher_id, :target_teacher_id, :teacher_id, :therapy_station_id, :therapy_room_id ]
          ).to_h
        end
      end
    end
  end
end
