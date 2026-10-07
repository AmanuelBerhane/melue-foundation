# frozen_string_literal: true

module Api
  module V1
    module ProgramDirector
      # FR-054 (Assessment Review), FR-055 (Summary Report), FR-056 (Visualizations)
      class AssessmentsController < Api::V1::BaseController
        include Authorization

        before_action :authenticate_user!
        before_action :require_program_director

        # GET /api/v1/program_director/assessments
        #
        # @oas_include
        # @summary List assessment reviews with pagination and status filtering
        # @tags Program Director
        # @auth [bearer_jwt]
        # @parameter status(query) [String] Filter by status (in_progress, complete, reviewed)
        # @parameter page(query) [Integer] Page number (default: 1)
        # @parameter per_page(query) [Integer] Items per page (default: 20, max: 100)
        # @response (200) Hash{ assessments: Array<Hash>, pagination: Hash }
        # @response (403) Hash{ error: String }
        def index
          result = ::ProgramDirector::AssessmentReviewService.call(
            status: params[:status],
            page: params[:page],
            per_page: params[:per_page]
          )

          if result.success?
            render json: result.data, status: :ok
          else
            render_error(result.error, :unprocessable_content)
          end
        end

        # GET /api/v1/program_director/assessments/:id
        #
        # @oas_include
        # @summary Get complete assessment summary report and visualization data
        # @tags Program Director
        # @auth [bearer_jwt]
        # @parameter id(path) [String] UUID of the assessment cycle or student
        # @response (200) Hash{ student: Hash, assessment: Hash, skills: Hash, behavior: Hash, preferences: Hash, visualizations: Hash }
        # @response (404) Hash{ error: String }
        # @response (403) Hash{ error: String }
        def show
          result = ::ProgramDirector::AssessmentSummaryService.call(
            assessment_cycle_id: params[:id]
          )

          if result.success?
            render json: result.data, status: :ok
          else
            render_error(result.error, :not_found)
          end
        end
      end
    end
  end
end
