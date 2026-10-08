# app/controllers/api/v1/teacher/behavior_assessments_controller.rb
module Api
  module V1
    module Teacher
      class BehaviorAssessmentsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_student

        def show
          mass_assessment = MassAssessment.where(student_id: @student.id).order(created_at: :desc).first
          fast_assessment = FastAssessment.where(student_id: @student.id).order(created_at: :desc).first

          mass_sc = mass_assessment&.function_scores || { sensory: 0, escape: 0, attention: 0, tangible: 0 }
          fast_sc = fast_assessment&.function_scores || { sensory: 0, escape: 0, attention: 0, tangible: 0 }

          combined_scores = {
            sensory: mass_sc[:sensory].to_i + fast_sc[:sensory].to_i,
            escape: mass_sc[:escape].to_i + fast_sc[:escape].to_i,
            attention: mass_sc[:attention].to_i + fast_sc[:attention].to_i,
            tangible: mass_sc[:tangible].to_i + fast_sc[:tangible].to_i
          }

          render json: {
            status: "success",
            data: {
              student_id: @student.id,
              student_name: @student.full_name,
              massAnswers: mass_assessment&.responses || {},
              fastAnswers: fast_assessment&.responses || {},
              records: [],
              scores: combined_scores,
              function_scores: combined_scores,
              mass_scores: mass_sc,
              fast_scores: fast_sc,
              dominant_function: mass_assessment&.dominant_function || "Sensory",
              hypothesized_function: fast_assessment&.hypothesized_function || "Sensory",
              risk_indicators: fast_assessment&.risk_indicators || {},
              status: mass_assessment&.status || "draft"
            }
          }
        end

        def create
          # Handle MASS assessment
          mass_answers = params[:massAnswers] || params[:mass_responses]
          mass_assessment = MassAssessment.where(student_id: @student.id, status: "draft").order(created_at: :desc).first
          mass_assessment ||= MassAssessment.new(student: @student, teacher: current_user&.staff_member, status: "draft")

          if mass_answers.present?
            raw = mass_answers.respond_to?(:to_unsafe_h) ? mass_answers.to_unsafe_h : (mass_answers.is_a?(Hash) ? mass_answers : {})
            mass_assessment.responses = (mass_assessment.responses || {}).merge(raw)
            mass_assessment.calculate_scores!
          else
            mass_assessment.calculate_scores!
          end

          # Handle FAST assessment
          fast_answers = params[:fastAnswers] || params[:fast_responses]
          fast_assessment = FastAssessment.where(student_id: @student.id, status: "draft").order(created_at: :desc).first
          fast_assessment ||= FastAssessment.new(student: @student, teacher: current_user&.staff_member, status: "draft")

          if fast_answers.present?
            raw = fast_answers.respond_to?(:to_unsafe_h) ? fast_answers.to_unsafe_h : (fast_answers.is_a?(Hash) ? fast_answers : {})
            fast_assessment.responses = (fast_assessment.responses || {}).merge(raw)
            fast_assessment.calculate_risks!
          else
            fast_assessment.calculate_risks!
          end

          if params[:status] == "submitted" || params[:status] == "completed"
            mass_assessment.status = "completed"
            mass_assessment.completed_at = Time.current
            fast_assessment.status = "completed"
            fast_assessment.completed_at = Time.current
          end

          mass_assessment.save!
          fast_assessment.save!

          mass_sc = mass_assessment.function_scores
          fast_sc = fast_assessment.function_scores

          combined_scores = {
            sensory: mass_sc[:sensory].to_i + fast_sc[:sensory].to_i,
            escape: mass_sc[:escape].to_i + fast_sc[:escape].to_i,
            attention: mass_sc[:attention].to_i + fast_sc[:attention].to_i,
            tangible: mass_sc[:tangible].to_i + fast_sc[:tangible].to_i
          }

          render json: {
            status: "success",
            data: {
              student_id: @student.id,
              massAnswers: mass_assessment.responses,
              fastAnswers: fast_assessment.responses,
              records: params[:records] || [],
              scores: combined_scores,
              function_scores: combined_scores,
              mass_scores: mass_sc,
              fast_scores: fast_sc,
              dominant_function: mass_assessment.dominant_function,
              hypothesized_function: fast_assessment.hypothesized_function,
              risk_indicators: fast_assessment.risk_indicators,
              status: mass_assessment.status
            }
          }
        end

        private

        def set_student
          @student = Student.find_by(id: params[:student_id])
          render json: { error: "Student not found" }, status: :not_found unless @student
        end
      end
    end
  end
end
