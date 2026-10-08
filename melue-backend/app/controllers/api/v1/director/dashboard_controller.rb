# frozen_string_literal: true

module Api
  module V1
    module Director
      # SCR-DIR-001 — Director Dashboard
      class DashboardController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_director_or_admin

        # @oas_include
        # @summary Live operational counts for the Director dashboard
        # @tags Director
        # @auth [bearer_jwt]
        # @response Success (200) [Hash{ data: Hash }]
        # @response_example Success (200) [JSON{ "data": { "date": "2026-10-03", "generated_at": "2026-10-03T09:15:00Z", "students": { "total_active": 24, "in_assessment": 5, "ready_for_iup": 2 }, "staff": { "total_teachers": 8, "teachers_on_duty": 7, "teachers_unavailable": 1 }, "sessions": { "in_progress": 4, "students_in_session": 8, "rooms_in_use": 4, "completed_today": 6 }, "scheduling": { "assignments_today": 40, "students_scheduled_today": 22, "unassigned_active_students": 2, "capacity_per_teacher": 4 }, "reviews": { "session_summaries_pending_review": 3, "mastery_checks_pending_approval": 1 }, "activity": { "trials_logged_today": 312, "behavior_incidents_today": 2, "goals_mastered_this_month": 5 } } }]
        # @response Unauthorized (401) [Hash{ error: String }]
        # @response Forbidden (403) [Hash{ error: String }]
        # GET /api/v1/director/dashboard
        def show
          result = ::Director::DashboardService.call
          render json: { data: result.data }, status: :ok
        end
      end
    end
  end
end
