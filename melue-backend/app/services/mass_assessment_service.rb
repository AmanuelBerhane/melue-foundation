# app/services/mass_assessment_service.rb
class MassAssessmentService < ApplicationService
  attr_reader :student, :params, :current_user

  def initialize(student, params = {}, current_user = nil)
    @student = student
    @params = params
    @current_user = current_user
  end

  def start
    return failure("Student not found") unless student

    assessment = MassAssessment.create!(
      student: student,
      status: "draft"
    )

    success(assessment)
  end

  def submit
    assessment = MassAssessment.find_by(id: params[:id], student_id: student.id)
    return failure("Assessment not found") unless assessment

    assessment.calculate_scores!
    assessment.status = "completed"
    assessment.completed_at = Time.current

    if assessment.save
      success(assessment)
    else
      failure(assessment.errors.full_messages.join(", "))
    end
  end

  def update_responses
    assessment = MassAssessment.find_by(id: params[:id], student_id: student.id)
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
