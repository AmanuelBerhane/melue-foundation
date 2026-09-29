# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Therapy Sessions Behavior Incidents API", type: :request do
  let(:user) { create(:user, :therapist) }
  let(:teacher) { create(:staff_member, :teacher, user: user) }
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

  let(:headers) { auth_headers(user) }

  let(:valid_params) do
    {
      behavior_name: "Flopping",
      frequency: "frequently",
      intensity: "moderate",
      antecedent: "Task demand",
      consequence: "Sensory break",
      location: "Therapy room",
      additional_notes: "Observed during table activity"
    }
  end

  describe "GET /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents" do
    it "returns all incidents logged for this session" do
      create(:behavior_incident, therapy_session: session, student: student, staff_member: teacher)
      create(:behavior_incident, therapy_session: session, student: student, staff_member: teacher)
      create(:behavior_incident) # other session

      get "/api/v1/therapy_sessions/#{session.id}/behavior_incidents", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json.size).to eq(2)
      expect(json.first["therapy_session_id"]).to eq(session.id)
    end
  end

  describe "POST /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents" do
    it "records an incident linked to session, student, active goal, and teacher" do
      expect {
        post "/api/v1/therapy_sessions/#{session.id}/behavior_incidents",
             params: valid_params,
             headers: headers
      }.to change(BehaviorIncident, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["therapy_session_id"]).to eq(session.id)
      expect(json["student_id"]).to eq(student.id)
      expect(json["student_goal_id"]).to eq(student_goal.id)
      expect(json["staff_member_id"]).to eq(teacher.id)
      expect(json["behavior_name"]).to eq("Flopping")
      expect(json["behavior_definition"]).to eq("Throwing self on the floor suddenly")
      expect(json["category"]).to eq("flopping")
      expect(json["teacher_name"]).to eq(teacher.full_name)
    end

    it "returns unprocessable content if validation fails" do
      post "/api/v1/therapy_sessions/#{session.id}/behavior_incidents",
           params: { behavior_name: "" },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to be_present
    end

    it "returns forbidden if teacher is not assigned to this session" do
      other_user = create(:user, :therapist)
      create(:staff_member, :teacher, user: other_user)
      other_headers = auth_headers(other_user)

      post "/api/v1/therapy_sessions/#{session.id}/behavior_incidents",
           params: valid_params,
           headers: other_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/therapy_sessions/:therapy_session_id/behavior_incidents/options" do
    it "returns modal dropdown options with session context" do
      get "/api/v1/therapy_sessions/#{session.id}/behavior_incidents/options", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["behaviors"]).to be_an(Array)
      expect(json["frequencies"]).to be_an(Array)
      expect(json["intensities"]).to be_an(Array)
      expect(json["categories"]).to be_an(Array)
      expect(json["antecedents"]).to be_an(Array)
      expect(json["consequences"]).to be_an(Array)
      expect(json["locations"]).to be_an(Array)

      context = json["context"]
      expect(context["session_id"]).to eq(session.id)
      expect(context["teacher"]["id"]).to eq(teacher.id)
      expect(context["active_participant"]["student_id"]).to eq(student.id)
      expect(context["active_participant"]["active_goal"]["id"]).to eq(student_goal.id)
    end
  end
end
