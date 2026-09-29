# frozen_string_literal: true

require "rails_helper"

RSpec.describe BehaviorIncidentSerializer do
  let(:student) { create(:student, first_name: "John", last_name: "Doe") }
  let(:staff_member) { create(:staff_member, full_name: "Teacher Alice") }
  let(:session) { create(:therapy_session) }
  let(:student_goal) { create(:student_goal, student: student) }
  let(:incident) do
    create(
      :behavior_incident,
      student: student,
      staff_member: staff_member,
      therapy_session: session,
      student_goal: student_goal,
      behavior_name: "Elopement",
      behavior_definition: "Running away from supervision",
      frequency: :frequently,
      intensity: :moderate,
      category: :safety_concerns,
      antecedent: "Transition",
      consequence: "Redirected",
      location: "Playground",
      additional_notes: "Followed protocol",
      occurred_at: Time.zone.parse("2026-08-15 10:30:00")
    )
  end

  it "serializes a behavior incident with complete ABC context" do
    result = described_class.new(incident).as_json

    expect(result[:id]).to eq(incident.id)
    expect(result[:student_id]).to eq(student.id)
    expect(result[:student_name]).to eq(student.full_name)
    expect(result[:staff_member_id]).to eq(staff_member.id)
    expect(result[:teacher_name]).to eq("Teacher Alice")
    expect(result[:therapy_session_id]).to eq(session.id)
    expect(result[:student_goal_id]).to eq(student_goal.id)
    expect(result[:behavior_name]).to eq("Elopement")
    expect(result[:behavior_definition]).to eq("Running away from supervision")
    expect(result[:frequency]).to eq("frequently")
    expect(result[:frequency_label]).to eq("Frequently")
    expect(result[:intensity]).to eq("moderate")
    expect(result[:intensity_label]).to eq("Moderate")
    expect(result[:category]).to eq("safety_concerns")
    expect(result[:category_label]).to eq("Safety Concerns")
    expect(result[:antecedent]).to eq("Transition")
    expect(result[:consequence]).to eq("Redirected")
    expect(result[:location]).to eq("Playground")
    expect(result[:additional_notes]).to eq("Followed protocol")
    expect(result[:date]).to eq("2026-08-15")
    expect(result[:time]).to eq("10:30")
  end

  it "serializes collection of incidents" do
    create_list(:behavior_incident, 2, student: student)
    result = described_class.new(BehaviorIncident.where(student: student)).as_json
    expect(result).to be_an(Array)
    expect(result.size).to eq(2)
  end
end
