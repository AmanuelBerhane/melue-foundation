# app/controllers/api/v1/students/behavior_incidents_controller.rb
class Api::V1::Students::BehaviorIncidentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_student
  before_action :set_incident, only: [ :update, :destroy ]

  # @oas_include
  # @summary List behavior incidents for a student
  # @tags Behavior Incidents
  # @auth [bearer_jwt]
  #
  # @parameter student_id(path) [!String] Student ID
  # @parameter start_date(query) [String] Start date (YYYY-MM-DD)
  # @parameter end_date(query) [String] End date (YYYY-MM-DD)
  def index
    incidents = BehaviorIncident.for_student(@student.id)

    if params[:start_date].present? && params[:end_date].present?
      incidents = incidents.for_date_range(params[:start_date].to_date, params[:end_date].to_date)
    end

    render json: incidents.order(occurred_at: :desc)
  end

  # @oas_include
  # @summary Create a behavior incident
  # @tags Behavior Incidents
  # @auth [bearer_jwt]
  #
  # @request_body Incident data [Hash{ behavior_name: !String, frequency: !String, intensity: !String, category: !String, antecedent: !String, consequence: !String, location: !String }]
  #
  # @response Created (201) [BehaviorIncident]
  def create
    service = Assessments::BehaviorIncidentService.new(@student, params, current_user)
    result = service.create

    if result.success?
      render json: result.data, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Update a behavior incident
  # @tags Behavior Incidents
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!String] Incident ID
  # @request_body Incident data [Hash{ behavior_name: String, frequency: String, etc }]
  def update
    service = Assessments::BehaviorIncidentService.new(@student, params, current_user, @incident)
    result = service.update

    if result.success?
      render json: result.data
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Delete a behavior incident
  # @tags Behavior Incidents
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!String] Incident ID
  def destroy
    service = Assessments::BehaviorIncidentService.new(@student, params, current_user, @incident)
    result = service.destroy

    if result.success?
      render json: { message: result.data }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  private

  def set_student
    @student = Student.find(params[:student_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student not found" }, status: :not_found
  end

  def set_incident
    @incident = BehaviorIncident.find_by(id: params[:id], student_id: @student.id)
    render json: { error: "Incident not found" }, status: :not_found unless @incident
  end
end
