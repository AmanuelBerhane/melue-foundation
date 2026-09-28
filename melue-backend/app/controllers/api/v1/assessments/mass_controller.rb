# app/controllers/api/v1/assessments/mass_controller.rb
module Api
  module V1
    module Assessments
      class MassController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_student

        def create
          service = MassAssessmentService.new(@student, params, current_user)
          result = service.start

          if result.success?
            render json: result.data, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        def update
          service = MassAssessmentService.new(@student, params.merge(id: params[:id]), current_user)
          result = service.update_responses

          if result.success?
            render json: result.data
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        def submit
          service = MassAssessmentService.new(@student, params.merge(id: params[:id]), current_user)
          result = service.submit

          if result.success?
            render json: result.data
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        private

        def set_student
          @student = Student.find(params[:student_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Student not found" }, status: :not_found
        end
      end
    end
  end
end
