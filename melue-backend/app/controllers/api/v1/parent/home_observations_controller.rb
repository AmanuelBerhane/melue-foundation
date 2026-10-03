# frozen_string_literal: true

module Api
  module V1
    module Parent
      # SCR-PAR-003 — Home observations recorded by the guardian
      class HomeObservationsController < BaseController
        before_action :guardian_student!

        # @oas_include
        # @summary List home observations for a child
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter student_id(path) [!String] Student ID
        # @response Success (200) [Hash{ data: Array<Hash>, meta: Hash }]
        # @response Not Found (404) [Hash{ error: String }]
        # GET /api/v1/parent/students/:student_id/home_observations
        def index
          observations, meta = paginated(@student.home_observations.chronological)
          render json: { data: HomeObservationSerializer.new(observations).as_json, meta: meta }
        end

        # @oas_include
        # @summary Record a home observation for a child
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter student_id(path) [!String] Student ID
        # @request_body Observation [!Hash{ content: String, observed_on: String }]
        # @request_body_example [JSON{ "content": "Used two-word requests at dinner.", "observed_on": "2026-10-02" }]
        # @response Created (201) [Hash{ data: Hash }]
        # @response Unprocessable Entity (422) [Hash{ error: Array<String> }]
        # POST /api/v1/parent/students/:student_id/home_observations
        def create
          observation = @student.home_observations.new(
            guardian: current_guardian,
            content: params[:content].to_s.strip,
            observed_on: parse_observed_on,
            submitted_at: Time.current
          )

          if observation.save
            render json: { data: HomeObservationSerializer.new(observation).as_json }, status: :created
          else
            render_error(observation.errors.full_messages, :unprocessable_entity)
          end
        end

        private

        def parse_observed_on
          params[:observed_on].present? ? Date.iso8601(params[:observed_on].to_s) : Date.current
        rescue Date::Error
          nil
        end
      end
    end
  end
end
