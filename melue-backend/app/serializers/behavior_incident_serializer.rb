# frozen_string_literal: true

class BehaviorIncidentSerializer < ApplicationSerializer
  private

  def serialize(incident)
    {
      id: incident.id,
      student_id: incident.student_id,
      student_name: incident.student&.full_name,
      staff_member_id: incident.staff_member_id,
      teacher_name: incident.staff_member&.full_name,
      therapy_session_id: incident.therapy_session_id,
      student_goal_id: incident.student_goal_id,
      goal_name: incident.student_goal&.goal_name,
      behavior_name: incident.behavior_name,
      behavior_definition: incident.behavior_definition,
      frequency: incident.frequency,
      frequency_label: incident.frequency&.to_s&.titleize,
      intensity: incident.intensity,
      intensity_label: incident.intensity&.to_s&.titleize,
      category: incident.category,
      category_label: incident.category&.to_s&.titleize,
      antecedent: incident.antecedent,
      consequence: incident.consequence,
      location: incident.location,
      occurred_at: incident.occurred_at,
      date: incident.occurred_at&.to_date&.to_s,
      time: incident.occurred_at&.strftime("%H:%M"),
      additional_notes: incident.additional_notes,
      created_at: incident.created_at,
      updated_at: incident.updated_at
    }
  end
end
