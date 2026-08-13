# frozen_string_literal: true

class Api::V1::StudentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!

  # GET /api/v1/students
  def index
    result = Students::ListService.call(current_user: current_user, params: filter_params)

    render json: { success: true, data: StudentSerializer.new(result.data[:students]).as_json, meta: result.data[:meta] }
  end

  # GET /api/v1/students/:id
  def show
    result = Students::ProfileService.call(student_id: params[:id], current_user: current_user)

    return render_service_error(result) unless result.success?

    render json: { success: true, data: result.data }
  end

  # POST /api/v1/students
  def create
    result = Students::RegisterService.call(params: student_params, current_user: current_user)

    return render_service_error(result) unless result.success?

    render json: { success: true, data: StudentSerializer.new(result.data).as_json }, status: :created
  end

  # PATCH /api/v1/students/:id
  def update
    result = Students::UpdateService.call(student_id: params[:id], params: student_params, current_user: current_user)

    return render_service_error(result) unless result.success?

    render json: { success: true, data: StudentSerializer.new(result.data[:student]).as_json, warning: result.data[:warning] }
  end

  private

  def require_staff_member!
    render json: { success: false, error: "Staff profile required", data: nil }, status: :forbidden unless current_staff_member
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end

  def filter_params
    params.permit(:q, :program_type, :therapy_group, :page, :per_page).to_h.symbolize_keys
  end

  def student_params
    params.permit(
      :first_name, :middle_name, :last_name,
      :date_of_birth, :program_type, :therapy_group,
      :diagnosis, :guardian_name, :guardian_phone, :headshot
    ).to_h.symbolize_keys
  end

  def render_service_error(result)
    status = result.error&.match?(/permission/i) ? :forbidden : :unprocessable_entity
    render json: { success: false, error: result.error, data: nil }, status: status
  end
end
