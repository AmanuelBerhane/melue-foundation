# app/controllers/api/v1/program_directors/caseload_controller.rb
class Api::V1::ProgramDirectors::CaseloadController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_program_director!

  # @oas_include
  # @summary Get Program Director's caseload
  # @tags Caseload
  # @auth [bearer_jwt]
  #
  # @parameter search(query) [String] Search by student name
  # @parameter program_type(query) [String] Filter by program type (regular, pulled_out)
  # @parameter therapy_group(query) [String] Filter by therapy group (basic, functional_living)
  # @parameter status(query) [String] Filter by student status
  #
  # @response Success (200) [Array<Student>]
  def index
    filters = {
      search: params[:search],
      program_type: params[:program_type],
      therapy_group: params[:therapy_group],
      status: params[:status]
    }.compact

    service = Students::CaseloadService.new(current_staff_member, filters)
    result = service.call

    if result.success?
      render json: {
        students: result.data,
        count: result.data.count,
        filters: filters
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  private

  def require_program_director!
    unless current_staff_member&.role_program_director?
      render json: { error: "Unauthorized - Program Director access required" }, status: :forbidden
    end
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
