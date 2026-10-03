# app/controllers/api/v1/assessments/fast_controller.rb
module Api
  module V1
    module Assessments
      class FastController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_student

        def show
          assessment = FastAssessment.find_by(id: params[:id], student_id: @student.id)
          return render json: { error: "Assessment not found" }, status: :not_found unless assessment

          render json: serialize_assessment(assessment)
        end

        def create
          service = FastAssessmentService.new(@student, params, current_user)
          result = service.start

          if result.success?
            render json: serialize_assessment(result.data), status: :created
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        def update
          service = FastAssessmentService.new(@student, params.merge(id: params[:id]), current_user)
          result = service.update_responses

          if result.success?
            render json: serialize_assessment(result.data)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        def submit
          service = FastAssessmentService.new(@student, params.merge(id: params[:id]), current_user)
          result = service.submit

          if result.success?
            render json: serialize_assessment(result.data)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        private

        def set_student
          if params[:student_id].present?
            @student = Student.find_by(id: params[:student_id])
          elsif params[:id].present?
            assessment = FastAssessment.find_by(id: params[:id])
            @student = assessment&.student
          end

          render json: { error: "Student not found" }, status: :not_found unless @student
        end

        def serialize_assessment(assessment)
          assessment.as_json.merge(
            "risk_indicators" => assessment.risk_indicators,
            "scores" => assessment.scores,
            "function_scores" => assessment.function_scores,
            "hypothesized_function" => assessment.hypothesized_function
          )
        end
      end
    end
  end
end
