# app/services/assessments/fast_service.rb
module Assessments
  class FastService < ApplicationService
    attr_reader :student, :params, :current_user

    def initialize(student, params = {}, current_user = nil)
      @student = student
      @params = params
      @current_user = current_user
    end

    def start
      return failure("Student not found") unless student

      assessment = FastAssessment.create!(
        student: student,
        status: "draft",
        teacher: current_user&.staff_member
      )

      success(assessment)
    end

    def submit
      assessment = FastAssessment.find_by(id: params[:id], student_id: student.id)
      return failure("Assessment not found") unless assessment

      # Calculate risk indicators
      assessment.calculate_risks!

      # Mark as completed
      assessment.status = "completed"
      assessment.completed_at = Time.current

      if assessment.save
        success(assessment)
      else
        failure(assessment.errors.full_messages.join(", "))
      end
    end

    def update_responses
      assessment = FastAssessment.find_by(id: params[:id], student_id: student.id)
      return failure("Assessment not found") unless assessment
      return failure("Assessment already completed") if assessment.completed?

      assessment.responses = params[:responses]

      if assessment.save
        success(assessment)
      else
        failure(assessment.errors.full_messages.join(", "))
      end
    end
  end
end
