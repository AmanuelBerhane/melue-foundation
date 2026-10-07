# frozen_string_literal: true

module Api
  module V1
    module ProgramDirector
      # FR-052: Program Director Dashboard Controller
      # SCR-PD-001 — Program Director Dashboard
      class DashboardController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_program_director

        # GET /api/v1/program_director/dashboard
        #
        # @oas_include
        # @summary Program Director Dashboard metrics
        # @tags Program Director
        # @auth [bearer_jwt]
        # @response (200) Hash{ students_in_assessment: Integer, assessment_complete: Integer, active_iup_plans: Integer, goals_assigned_this_month: Integer }
        # @response (403) Hash{ error: String }
        def show
          result = ::ProgramDirector::DashboardService.call

          if result.success?
            render json: result.data, status: :ok
          else
            render_error(result.error, :unprocessable_content)
          end
        end
      end
    end
  end
end
