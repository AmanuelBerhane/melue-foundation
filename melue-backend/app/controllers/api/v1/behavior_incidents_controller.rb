# frozen_string_literal: true

module Api
  module V1
    # Global options for the Behavior Incident Modal (SCR-003, FR-098, FR-098a, FR-098b)
    class BehaviorIncidentsController < Api::V1::BaseController
      before_action :authenticate_user!

      # GET /api/v1/behavior_incidents/options
      #
      # Returns all configurable dropdown fields, options, and auto-populated definitions.
      #
      # @oas_include
      # @summary Get behavior incident modal dropdown options
      # @tags Behavior Incidents
      # @auth [bearer_jwt]
      # @response (200) Hash
      def options
        render json: BehaviorIncident.modal_options, status: :ok
      end
    end
  end
end
