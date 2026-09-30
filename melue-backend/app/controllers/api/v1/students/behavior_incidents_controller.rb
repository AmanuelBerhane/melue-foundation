# app/controllers/api/v1/students/behavior_incidents_controller.rb
class Api::V1::Students::BehaviorIncidentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_student
  before_action :set_incident, only: [ :update, :destroy ]

  def index
    incidents = BehaviorIncident.for_student(@student.id)
    incidents = incidents.for_date_range(params[:start_date], params[:end_date]) if params[:start_date].present?
    render json: incidents.order(occurred_at: :desc)
  end

  def options
    context = {
      student_id: @student.id,
      student_name: @student.full_name,
      teacher: current_staff_member ? { id: current_staff_member.id, name: current_staff_member.full_name } : nil,
      current_date: Date.current.to_s,
      current_time: Time.current.strftime("%H:%M")
    }
    render json: BehaviorIncident.modal_options.merge(context: context), status: :ok
  end

  def create
    incident = @student.behavior_incidents.build(incident_params)
    incident.staff_member = current_staff_member if current_staff_member.present?

    # FR-098c: Auto-link active goal if session is provided without goal
    if incident.student_goal_id.blank? && incident.therapy_session.present?
      participant = incident.therapy_session.session_participants.find_by(student_id: @student.id)
      incident.student_goal_id = participant&.current_focus_student_goal_id ||
                                 @student.student_goals.where(
                                   therapy_station_id: incident.therapy_session.therapy_station_id,
                                   status: %w[active in_progress]
                                 ).order(updated_at: :desc).first&.id
    end

    incident.set_defaults

    if incident.save
      render json: incident, status: :created
    else
      render json: { error: incident.errors.full_messages.join(", ") }, status: :unprocessable_content
    end
  end

  def update
    if @incident.update(incident_params)
      render json: @incident
    else
      render json: { error: @incident.errors.full_messages.join(", ") }, status: :unprocessable_content
    end
  end

  def destroy
    @incident.destroy
    render json: { message: "Incident deleted successfully" }
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def set_incident
    @incident = @student.behavior_incidents.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Incident not found" }, status: :not_found
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
