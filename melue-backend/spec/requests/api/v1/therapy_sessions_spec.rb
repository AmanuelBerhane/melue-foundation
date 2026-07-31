# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapySessions", type: :request do
  let(:user)    { create(:user) }
  let(:teacher) { create(:staff_member, user: user) }
  let(:station) { create(:therapy_station) }
  let(:room)    { create(:therapy_room, therapy_station: station) }
  let(:block)   { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:headers) { authenticated_headers(user) }

  let!(:assignment1) do
    create(:teacher_student_assignment,
           teacher: teacher, student: student1,
           session_block_definition: block,
           therapy_station: station, therapy_room: room,
           scheduled_date: Date.current)
  end

  let!(:assignment2) do
    create(:teacher_student_assignment,
           teacher: teacher, student: student2,
           session_block_definition: block,
           therapy_station: station, therapy_room: room,
           scheduled_date: Date.current)
  end

  # ── GET /api/v1/today/session ──────────────────────────────────────────────
  describe "GET /api/v1/today/session" do
    context "when the teacher has an assignment today" do
      it "returns 200 with assignment context and prompt levels" do
        get "/api/v1/today/session", headers: headers
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["assignment"]).to be_present
        expect(json["prompt_levels"]).to be_an(Array)
      end
    end

    context "when the teacher has no assignment today" do
      it "returns 404" do
        assignment1.update_column(:scheduled_date, Date.current - 1.day)
        assignment2.update_column(:scheduled_date, Date.current - 1.day)
        get "/api/v1/today/session", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/today/session"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/therapy_sessions/start ───────────────────────────────────
  describe "POST /api/v1/therapy_sessions/start" do
    it "returns 201 and creates a session" do
      expect {
        post "/api/v1/therapy_sessions/start",
             params: { assignment_id: assignment1.id },
             headers: headers
      }.to change(TherapySession, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["session"]["status"]).to eq("in_progress")
    end

    it "is idempotent — returns existing session on repeat" do
      post "/api/v1/therapy_sessions/start",
           params: { assignment_id: assignment1.id },
           headers: headers

      expect {
        post "/api/v1/therapy_sessions/start",
             params: { assignment_id: assignment1.id },
             headers: headers
      }.not_to change(TherapySession, :count)

      expect(response).to have_http_status(:created)
    end

    it "returns 404 when assignment does not exist" do
      post "/api/v1/therapy_sessions/start",
           params: { assignment_id: SecureRandom.uuid },
           headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── GET /api/v1/therapy_sessions/:id/dashboard ────────────────────────────
  describe "GET /api/v1/therapy_sessions/:id/dashboard" do
    let(:session) do
      TherapySessions::StartService.call(
        assignment: assignment1,
        staff_member: teacher
      ).data
    end

    it "returns 200 with station, room, block, participants and prompt levels" do
      get "/api/v1/therapy_sessions/#{session.id}/dashboard", headers: headers
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json["station"]).to be_present
      expect(json["room"]).to be_present
      expect(json["block"]).to be_present
      expect(json["participants"].length).to eq(2)
      expect(json["prompt_levels"]).to be_an(Array)
    end

    it "returns 404 for an unknown session" do
      get "/api/v1/therapy_sessions/#{SecureRandom.uuid}/dashboard", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── PATCH /api/v1/therapy_sessions/:id/participants/:participant_id/active_goal
  describe "PATCH /api/v1/therapy_sessions/:id/participants/:participant_id/active_goal" do
    let(:session) do
      TherapySessions::StartService.call(
        assignment: assignment1,
        staff_member: teacher
      ).data
    end

    let(:participant) { session.active_participant }
    let(:iup)         { create(:iup, student: participant.student) }
    let(:goal)        { create(:student_goal, student: participant.student, iup: iup, therapy_station: station) }

    it "returns 200 and updates the active goal" do
      patch "/api/v1/therapy_sessions/#{session.id}/participants/#{participant.id}/active_goal",
            params: { student_goal_id: goal.id },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(participant.reload.current_focus_student_goal_id).to eq(goal.id)
    end

    it "returns 422 when the goal does not belong to the participant's student" do
      other_goal = create(:student_goal, therapy_station: station)

      patch "/api/v1/therapy_sessions/#{session.id}/participants/#{participant.id}/active_goal",
            params: { student_goal_id: other_goal.id },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
