# app/controllers/api/v1/students/goals_controller.rb
class Api::V1::Students::GoalsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_program_director!
  before_action :set_student

  # @oas_include
  # @summary Get student's goals summary
  # @tags Student Goals
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @parameter include_mastered(query) [Boolean] Include mastered goals
  #
  # @response Success (200) [Hash{ student_id: String, stations: Array }]
  def show
    service = Students::GoalSummaryService.new(@student, include_mastered: params[:include_mastered] == "true")
    result = service.call

    # Check if result responds to success? method
    if result.respond_to?(:success?) && result.success?
      render json: result.data
    elsif result.is_a?(Hash)
      # If result is a hash directly, render it
      render json: result
    else
      error_message = result.respond_to?(:error) ? result.error : "Failed to fetch goal summary"
      render json: { error: error_message }, status: :not_found
    end
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def require_program_director!
    unless current_staff_member&.role_program_director?
      render json: { error: "Unauthorized - Program Director access required" }, status: :forbidden
    end
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
