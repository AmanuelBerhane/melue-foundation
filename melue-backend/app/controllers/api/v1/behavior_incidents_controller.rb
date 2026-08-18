# app/controllers/api/v1/behavior_incidents_controller.rb
class Api::V1::BehaviorIncidentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_student

  def index
    incidents = BehaviorIncident.for_student(@student.id)
    incidents = incidents.for_date_range(params[:start_date], params[:end_date]) if params[:start_date].present?
    render json: incidents.order(occurred_at: :desc)
  end

  def create
    incident = @student.behavior_incidents.build(incident_params)
    incident.staff_member = current_staff_member
    incident.set_behavior_definition

    if incident.save
      render json: incident, status: :created
    else
      render json: { error: incident.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update
    incident = @student.behavior_incidents.find(params[:id])

    if incident.update(incident_params)
      render json: incident
    else
      render json: { error: incident.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def destroy
    incident = @student.behavior_incidents.find(params[:id])
    incident.destroy
    render json: { message: "Incident deleted successfully" }
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def incident_params
    params.permit(
      :behavior_name, :behavior_definition, :frequency, :intensity,
      :category, :antecedent, :consequence, :location,
      :occurred_at, :additional_notes, :student_goal_id, :therapy_session_id
    )
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
