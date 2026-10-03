# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Parent portal", type: :request do
  let(:guardian) { create_parent_user }
  let(:headers) { authenticated_headers(guardian.user) }
  let(:child) { create(:student, first_name: "Abebe", status: "active_therapy") }
  let(:other_child) { create(:student) }

  before { create(:student_guardian, guardian: guardian, student: child) }

  describe "access control" do
    it "returns 403 for staff accounts" do
      get "/api/v1/parent/dashboard", headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq("Forbidden: Parent access required")
    end

    it "returns 401 without a token" do
      get "/api/v1/parent/dashboard"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for a child that is not the guardian's" do
      get "/api/v1/parent/students/#{other_child.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/parent/dashboard" do
    it "returns the guardian, their children and unread counts" do
      create(:parent_communication, student: child, guardian: guardian, direction: "outbound")
      create(:parent_communication, student: child, guardian: guardian, direction: "outbound", read_at: Time.current)
      create(:notification, recipient_user_id: guardian.user_id)

      get "/api/v1/parent/dashboard", headers: headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["guardian"]).to include("id" => guardian.id, "full_name" => guardian.full_name)
      expect(data["students"].map { |s| s["id"] }).to eq([ child.id ])
      expect(data["students"].first).to include("current_goals_summary")
      expect(data["students"].first).not_to have_key("internal_notes")
      expect(data).to include("unread_messages" => 1, "unread_notifications" => 1)
    end
  end

  describe "GET /api/v1/parent/students" do
    it "lists only the guardian's children with pagination meta" do
      other_child

      get "/api/v1/parent/students", headers: headers

      expect(response.parsed_body["data"].map { |s| s["id"] }).to eq([ child.id ])
      expect(response.parsed_body["meta"]).to eq("total" => 1, "limit" => 20, "offset" => 0)
    end

    it "shows a child's profile" do
      get "/api/v1/parent/students/#{child.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include("id" => child.id, "diagnosis" => child.diagnosis)
    end
  end

  describe "GET /api/v1/parent/students/:student_id/sessions" do
    it "returns only submitted/reviewed sessions with a trial breakdown" do
      assignment = create(:teacher_student_assignment, student: child)
      finished = create(:therapy_session)
      participant = create(:session_participant, therapy_session: finished, student: child,
                                                 teacher_student_assignment: assignment)
      finished.update!(status: "completed", ended_at: Time.current)
      create(:session_summary, therapy_session: finished, status: "submitted", submitted_at: Time.current)
      goal = create(:student_goal, student: child)
      create(:trial, therapy_session: finished, session_participant: participant, student_goal: goal, outcome: "correct")

      draft = create(:therapy_session)
      create(:session_participant, therapy_session: draft, student: child,
                                   teacher_student_assignment: create(:teacher_student_assignment, student: child,
                                                                      session_block_definition: create(:session_block_definition, :afternoon)))
      create(:session_summary, therapy_session: draft, status: "draft")

      get "/api/v1/parent/students/#{child.id}/sessions", headers: headers

      expect(response).to have_http_status(:ok)
      sessions = response.parsed_body["data"]
      expect(sessions.map { |s| s["id"] }).to eq([ finished.id ])
      expect(sessions.first["goals"].first).to include("student_goal_id" => goal.id, "total" => 1, "correct" => 1)
    end
  end

  describe "home observations" do
    let(:path) { "/api/v1/parent/students/#{child.id}/home_observations" }

    it "creates an observation stamped server-side" do
      expect {
        post path, params: { content: "Used two-word requests at dinner.", observed_on: "2026-10-02" },
                   headers: headers, as: :json
      }.to change(HomeObservation, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("guardian_id" => guardian.id, "observed_on" => "2026-10-02")
      expect(HomeObservation.last.submitted_at).to be_present
    end

    it "lists observations" do
      create(:home_observation, student: child, guardian: guardian)

      get path, headers: headers
      expect(response.parsed_body["data"].size).to eq(1)
    end

    it "returns 422 for blank content" do
      post path, params: { content: "" }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 when posting for someone else's child" do
      post "/api/v1/parent/students/#{other_child.id}/home_observations",
           params: { content: "x" }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "communications" do
    let(:path) { "/api/v1/parent/students/#{child.id}/communications" }

    it "lists the thread and sends inbound messages" do
      staff_message = create(:parent_communication, student: child, guardian: guardian, direction: "outbound")

      post path, params: { content: "Can we talk Friday?", direction: "outbound" }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("direction" => "inbound", "sender_id" => guardian.user_id)

      get path, headers: headers
      expect(response.parsed_body["data"].map { |m| m["id"] }.first).to eq(staff_message.id)
      expect(response.parsed_body["meta"]["total"]).to eq(2)
    end

    it "marks a message as read idempotently" do
      message = create(:parent_communication, student: child, guardian: guardian)

      patch "/api/v1/parent/communications/#{message.id}/mark_read", headers: headers
      first_read_at = message.reload.read_at
      patch "/api/v1/parent/communications/#{message.id}/mark_read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(message.reload.read_at).to eq(first_read_at)
    end

    it "cannot mark another guardian's message" do
      stranger = create_parent_user(guardian_name: "Someone Else")
      create(:student_guardian, guardian: stranger, student: other_child)
      message = create(:parent_communication, student: other_child, guardian: stranger)

      patch "/api/v1/parent/communications/#{message.id}/mark_read", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  it "rejects observations from a guardian not linked to the student" do
    observation = build(:home_observation, student: other_child, guardian: guardian)
    expect(observation).not_to be_valid
    expect(observation.errors[:guardian]).to include("is not linked to this student")
  end
end
