# app/services/fast_assessment_service.rb
class FastAssessmentService < ApplicationService
  attr_reader :student, :params, :current_user

  def initialize(student, params = {}, current_user = nil)
    @student = student
    @params = params
    @current_user = current_user
  end

  def start
    return failure("Student not found") unless student

    raw = extract_responses
    assessment = FastAssessment.new(
      student: student,
      status: "draft",
      teacher: current_user&.staff_member,
      responses: raw
    )
    assessment.calculate_risks! if raw.present?
    assessment.save!

    success(assessment)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.join(", "))
  end

  def submit
    assessment = FastAssessment.find_by(id: params[:id], student_id: student.id)
    return failure("Assessment not found") unless assessment

    raw = extract_responses
    if raw.present?
      merged = (assessment.responses || {}).merge(raw)
      assessment.responses = merged
    end

    assessment.calculate_risks!
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

    raw = extract_responses
    if raw.present?
      merged = (assessment.responses || {}).merge(raw)
      assessment.responses = merged
    end

    assessment.calculate_risks!

    if assessment.save
      success(assessment)
    else
      failure(assessment.errors.full_messages.join(", "))
    end
  end

  private

  def extract_responses
    raw = params[:responses] || params[:fastAnswers] || params[:answers] || params.dig(:fast_assessment, :responses) || params.dig(:assessment, :responses) || {}
    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : (raw.is_a?(Hash) ? raw : {})
  end
end
