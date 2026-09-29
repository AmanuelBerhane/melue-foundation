# app/services/assessments/behavior_incident_service.rb
module Assessments
  class BehaviorIncidentService < ApplicationService
    attr_reader :student, :params, :current_user, :incident

    def initialize(student, params = {}, current_user = nil, incident = nil)
      @student = student
      @params = params
      @current_user = current_user
      @incident = incident || BehaviorIncident.new(student: student)
    end

    def create
      return failure("Student not found") unless student

      incident.assign_attributes(
        staff_member: current_user&.staff_member,
        student_goal_id: params[:student_goal_id],
        therapy_session_id: params[:therapy_session_id],
        behavior_name: params[:behavior_name],
        behavior_definition: params[:behavior_definition],
        frequency: params[:frequency],
        intensity: params[:intensity],
        category: params[:category],
        antecedent: params[:antecedent],
        consequence: params[:consequence],
        location: params[:location],
        occurred_at: params[:occurred_at] || Time.current,
        additional_notes: params[:additional_notes]
      )

      # Auto-populate definition if not provided
      incident.set_behavior_definition

      if incident.save
        success(incident)
      else
        failure(incident.errors.full_messages.join(", "))
      end
    end

    def update
      return failure("Incident not found") unless incident.persisted?
      return failure("You don't have permission to edit this incident") unless authorized?

      incident.assign_attributes(
        behavior_name: params[:behavior_name] || incident.behavior_name,
        behavior_definition: params[:behavior_definition] || incident.behavior_definition,
        frequency: params[:frequency] || incident.frequency,
        intensity: params[:intensity] || incident.intensity,
        category: params[:category] || incident.category,
        antecedent: params[:antecedent] || incident.antecedent,
        consequence: params[:consequence] || incident.consequence,
        location: params[:location] || incident.location,
        occurred_at: params[:occurred_at] || incident.occurred_at,
        additional_notes: params[:additional_notes] || incident.additional_notes
      )

      if incident.save
        success(incident)
      else
        failure(incident.errors.full_messages.join(", "))
      end
    end

    def destroy
      return failure("Incident not found") unless incident.persisted?
      return failure("You don't have permission to delete this incident") unless authorized?

      if incident.destroy
        success("Incident deleted successfully")
      else
        failure(incident.errors.full_messages.join(", "))
      end
    end

    private

    def authorized?
      # Teachers can edit/delete their own incidents
      # Coordinators and Directors can edit/delete any
      current_user&.staff_member.present? && (
        incident.staff_member_id == current_user.staff_member.id ||
        current_user.staff_member&.role_therapy_coordinator? ||
        current_user.staff_member&.role_program_director?
      )
    end
  end
end
