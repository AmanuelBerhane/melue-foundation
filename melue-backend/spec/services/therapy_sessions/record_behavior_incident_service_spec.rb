# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapySessions::RecordBehaviorIncidentService do
  let(:teacher) { create(:staff_member, :teacher) }
  let(:session) { create(:therapy_session, teacher: teacher) }
  let(:student) { create(:student) }
  let(:student_goal) { create(:student_goal, student: student, therapy_station: session.therapy_station) }
  let!(:active_participant) do
    create(
      :session_participant,
      therapy_session: session,
      student: student,
      card_position: :active,
      current_focus_student_goal_id: student_goal.id
    )
  end

  let(:valid_params) do
    {
      behavior_name: "Elopement",
      frequency: "frequently",
      intensity: "moderate",
      antecedent: "Teacher asked to sit",
      consequence: "Guided back to seat",
      location: "Therapy room",
      additional_notes: "Calmed down after 2 minutes"
    }
  end

  it "records an incident automatically linked to session, student, active goal, and teacher" do
    result = described_class.call(
      session: session,
      staff_member: teacher,
      incident_params: valid_params
    )

    expect(result).to be_success
    incident = result.data
    expect(incident.therapy_session_id).to eq(session.id)
    expect(incident.student_id).to eq(student.id)
    expect(incident.student_goal_id).to eq(student_goal.id)
    expect(incident.staff_member_id).to eq(teacher.id)
    expect(incident.behavior_definition).to eq("Running or wandering away from supervision (moving away at least 5 feet)")
    expect(incident.category).to eq("safety_concerns")
  end

  it "allows explicit student_id and student_goal_id" do
    secondary_student = create(:student)
    secondary_goal = create(:student_goal, student: secondary_student, therapy_station: session.therapy_station)
    create(
      :session_participant,
      therapy_session: session,
      student: secondary_student,
      card_position: :secondary,
      current_focus_student_goal_id: secondary_goal.id
    )

    result = described_class.call(
      session: session,
      student_id: secondary_student.id,
      student_goal_id: secondary_goal.id,
      staff_member: teacher,
      incident_params: valid_params
    )

    expect(result).to be_success
    incident = result.data
    expect(incident.student_id).to eq(secondary_student.id)
    expect(incident.student_goal_id).to eq(secondary_goal.id)
  end

  it "fails if student is not a participant in the session" do
    outsider_student = create(:student)

    result = described_class.call(
      session: session,
      student_id: outsider_student.id,
      incident_params: valid_params
    )

    expect(result).to be_failure
    expect(result.error).to include("not a participant")
  end

  it "fails if required fields are missing" do
    result = described_class.call(
      session: session,
      incident_params: valid_params.except(:behavior_name)
    )

    expect(result).to be_failure
    expect(result.error).to include("Behavior name can't be blank")
  end
end
