# frozen_string_literal: true

module Api
  module V1
    module Coordinator
      # SCR-TC-002 — Live Session Monitoring
      class SessionsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_oversight_role

        # @oas_include
        # @summary Live snapshot of all in-progress therapy sessions (SCR-TC-002)
        # @tags Coordinator
        # @auth [bearer_jwt]
        # @parameter station_id(query) [String] Only sessions at this therapy station
        # @parameter room_id(query) [String] Only sessions in this therapy room
        # @parameter teacher_id(query) [String] Only sessions run by this teacher
        # @response Success (200) [Hash{ data: Hash{ generated_at: String, summary: Hash, sessions: Array<Hash> } }]
        # @response_example Success (200) [JSON{ "data": { "generated_at": "2026-10-03T09:15:00Z", "summary": { "active_sessions": 1, "students_in_session": 2, "rooms_in_use": 1, "trials_logged": 14 }, "sessions": [ { "id": "uuid", "status": "in_progress", "started_at": "2026-10-03T08:02:00Z", "elapsed_seconds": 4380, "block": { "id": "uuid", "name": "Morning Station 1", "round": "morning", "start_time": "08:00", "end_time": "09:30", "seconds_remaining": 900 }, "teacher": { "id": "uuid", "full_name": "Teacher A" }, "station": { "id": "uuid", "name": "Station 1" }, "room": { "id": "uuid", "name": "Room 1" }, "participants": [ { "id": "uuid", "card_position": "active", "student": { "id": "uuid", "full_name": "Abebe Kebede", "therapy_group": "basic" }, "current_focus_goal_id": "uuid", "goals": [ { "student_goal_id": "uuid", "goal_name": "Imitates gross motor actions", "goal_type": "standard", "status": "active", "progress_percent": 40.0, "is_current_focus": true, "trials": { "total": 10, "correct": 7, "incorrect": 2, "no_response": 1, "independence_percent": 40.0 }, "last_prompt": "+", "last_outcome": "correct", "last_trial_at": "2026-10-03T09:12:41Z" } ], "trials_logged": 10, "last_trial_at": "2026-10-03T09:12:41Z" } ], "trials_logged": 14, "incidents_count": 0, "last_activity_at": "2026-10-03T09:12:41Z" } ] } }]
        # @response Unauthorized (401) [Hash{ error: String }]
        # @response Forbidden (403) [Hash{ error: String }]
        # GET /api/v1/coordinator/sessions/active
        def active
          result = ::TherapyCoordinator::ActiveSessionsService.call(
            params.permit(:station_id, :room_id, :teacher_id).to_h.symbolize_keys
          )
          render json: { data: result.data }, status: :ok
        end
      end
    end
  end
end
