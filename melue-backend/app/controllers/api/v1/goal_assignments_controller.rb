# app/controllers/api/v1/goal_assignments_controller.rb
class Api::V1::GoalAssignmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_program_director!
  before_action :set_student, only: [ :create ]

  # @oas_include
  # @summary Assign a goal to a student
  # @tags Goal Assignments
  # @auth [bearer_jwt]
  #
  # @request_body Assignment data [Hash{ student_id: !String, goal_id: !String, station_id: !String, iup_id: String, notes: String }]
  #
  # @response Created (201) [StudentGoal]
  # @response_error Unprocessable (422) [Hash{ error: String }]
  def create
    service = Goals::AssignmentService.new(
      @student,
      params[:goal_id],
      params[:station_id],
      params[:iup_id],
      params[:notes],
      current_user
    )

    result = service.call

    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Replace a student goal with a new goal
  # @tags Goal Assignments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!String] Student Goal ID
  # @request_body Replacement data [Hash{ new_goal_id: !String }]
  #
  # @response Success (200) [Hash{ archived_goal: Hash, new_goal: Hash }]
  # @response_error Not Found (404) [Hash{ error: String }]
  def replace
    student_goal = StudentGoal.find(params[:id])
    service = Goals::ReplacementService.new(student_goal, params[:new_goal_id], current_user)
    result = service.call

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student goal not found" }, status: :not_found
  end

  # @oas_include
  # @summary Remove a goal from a student
  # @tags Goal Assignments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!String] Student Goal ID
  # @request_body Removal data [Hash{ reason: String }]
  #
  # @response Success (200) [Hash{ message: String }]
  # @response_error Not Found (404) [Hash{ error: String }]
  def destroy
    student_goal = StudentGoal.find(params[:id])
    service = Goals::RemovalService.new(student_goal, params[:reason], current_user)
    result = service.call

    if result.success?
      render json: { message: result.data[:message], student_goal: result.data[:student_goal] }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student goal not found" }, status: :not_found
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def require_program_director!
    # Check if user has a staff_member with program_director role
    staff_member = StaffMember.find_by(user_id: current_user.id)
    unless staff_member&.role_program_director?
      render json: { error: "Unauthorized - Program Director access required" }, status: :forbidden
    end
  end
end
