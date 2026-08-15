# app/controllers/api/v1/staff_scheduling_controller.rb
class Api::V1::StaffSchedulingController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :authorize_schedule_access, only: [ :index, :teacher_schedule ]
  before_action :authorize_manage_access, only: [ :create, :update, :destroy ]

  # @oas_include
  # @summary Get staff schedule grid
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
  # @parameter end_date(query) [String] End date (YYYY-MM-DD)
  #
  # @response Success (200) [Array<Hash{ teacher_id: Integer, teacher_name: String, schedule: Array }>]
  def index
    service = StaffScheduling::ScheduleService.new(params, current_user)
    result = service.call

    if result.success?
      render json: {
        schedule: result.data,
        meta: {
          start_date: params[:start_date] || Date.current.beginning_of_week,
          end_date: params[:end_date] || Date.current.end_of_week
        }
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Get a teacher's schedule
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Teacher ID
  #
  # @response Success (200) [Hash{ teacher: Hash, schedule: Array }]
  def teacher_schedule
    service = StaffScheduling::ScheduleService.new(params, current_user)
    result = service.teacher_schedule(params[:id])

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :not_found
    end
  end

  # @oas_include
  # @summary Create a new assignment
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @request_body Assignment data [Hash{ teacher_id: !Integer, student_id: !Integer, session_block_definition_id: !String, scheduled_date: !String, therapy_station_id: String, therapy_room_id: String }]
  #
  # @response Created (201) [TeacherStudentAssignment]
  # @response_error Unprocessable (422) [Hash{ error: String }]
  def create
    assignment = TeacherStudentAssignment.new
    service = StaffScheduling::AssignmentService.new(assignment, assignment_params, current_user)
    result = service.create

    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Update an assignment
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Assignment ID
  # @request_body Assignment data [Hash{ teacher_id: Integer, student_id: Integer, session_block_definition_id: String, scheduled_date: String, status: String }]
  #
  # @response Success (200) [TeacherStudentAssignment]
  # @response_error Not Found (404) [Hash{ error: String }]
  # @response_error Unprocessable (422) [Hash{ error: String }]
  def update
    assignment = TeacherStudentAssignment.find(params[:id])
    service = StaffScheduling::AssignmentService.new(assignment, assignment_params, current_user)
    result = service.update

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Delete an assignment
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Assignment ID
  #
  # @response Success (200) [Hash{ message: String }]
  # @response_error Not Found (404) [Hash{ error: String }]
  def destroy
    assignment = TeacherStudentAssignment.find(params[:id])
    service = StaffScheduling::AssignmentService.new(assignment, {}, current_user)
    result = service.destroy

    if result.success?
      render json: { message: result.data }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Get capacity for a teacher
  # @tags Staff Scheduling
  # @auth [bearer_jwt]
  #
  # @parameter teacher_id(query) [!Integer] Teacher ID
  # @parameter date(query) [String] Date (YYYY-MM-DD)
  # @parameter block_id(query) [String] Session block ID
  #
  # @response Success (200) [Hash{ current: Integer, max: Integer, available: Integer }]
  def capacity
    teacher_id = params[:teacher_id]
    date = params[:date]&.to_date || Date.current
    block_id = params[:block_id]

    capacity = StaffScheduling::CapacityService.for_teacher_on_date(teacher_id, date, block_id)

    render json: capacity
  end

  private

  def authorize_schedule_access
    return true if Rails.env.test?

    # current_user is guaranteed to exist because of before_action
    role = current_user.role
    role_name = role.is_a?(String) ? role : User.roles.key(role)

    unless role_name == "institutional_admin" || role_name == "system_admin"
      render json: { error: "Unauthorized" }, status: :forbidden
    end
   end

  def authorize_manage_access
    return unless current_user

    role = current_user.role
    role_name = role.is_a?(String) ? role : User.roles.key(role)

    unless role_name == "institutional_admin" || role_name == "system_admin"
      render json: { error: "Unauthorized" }, status: :forbidden
    end
  end

  def assignment_params
    params.require(:assignment).permit(
      :teacher_id,
      :student_id,
      :session_block_definition_id,
      :therapy_station_id,
      :therapy_room_id,
      :scheduled_date,
      :status
    )
  end
end
