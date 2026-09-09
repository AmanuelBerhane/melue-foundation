# frozen_string_literal: true

module Api
  module V1
    module ProgramDirector
      # FR-053: Assessment Pipeline Controller
      # Returns student progress across the 6-week assessment workflow stages:
      # Assessment → Assessment Complete → Review → Ready for IUP
      class AssessmentPipelineController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_program_director

        # GET /api/v1/program_director/assessment_pipeline
        #
        # @oas_include
        # @summary Program Director Assessment Pipeline
        # @tags Program Director
        # @auth [bearer_jwt]
        # @response (200) Hash{ pipeline: Array<Hash> }
        # @response (403) Hash{ error: String }
        def index
          result = ::ProgramDirector::AssessmentPipelineService.call

          if result.success?
            render json: { pipeline: result.data, students: result.data }, status: :ok
          else
            render_error(result.error, :unprocessable_entity)
          end
        end
      end
    end
  end
end
