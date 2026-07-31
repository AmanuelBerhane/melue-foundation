# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapySessions::Trials", type: :request do
  let(:user)    { create(:user) }
  let(:teacher) { create(:staff_member, user: user) }
  let(:station) { create(:therapy_station) }
  let(:room)    { create(:therapy_room, therapy_station: station) }
  let(:block)   { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:headers)  { authenticated_headers(user) }
  let(:prompt)   { create(:prompt_level, label: "FP", is_active: true) }

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

  let(:session) do
    TherapySessions::StartService.call(
      assignment: assignment1,
      staff_member: teacher
    ).data
  end

  let(:participant) { session.active_participant }
  let(:iup)         { create(:iup, student: participant.student) }
  let(:goal)        { create(:student_goal, student: participant.student, iup: iup, therapy_station: station) }

  # ── POST /api/v1/therapy_sessions/:session_id/trials ──────────────────────
  describe "POST /api/v1/therapy_sessions/:therapy_session_id/trials" do
    let(:trial_params) do
      {
        participation_id: participant.id,
        student_goal_id:  goal.id,
        prompt_level_id:  prompt.id,
        outcome:          "correct",
        client_event_id:  SecureRandom.uuid,
        logged_at:        Time.current.iso8601
      }
    end

    it "returns 201 and logs the trial" do
      expect {
        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: trial_params, headers: headers
      }.to change(Trial, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["trial"]["outcome"]).to eq("correct")
      expect(json["trial"]["prompt_label"]).to eq("FP")
    end

    it "returns 200 on duplicate client_event_id (idempotent)" do
      post "/api/v1/therapy_sessions/#{session.id}/trials",
           params: trial_params, headers: headers

      expect {
        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: trial_params, headers: headers
      }.not_to change(Trial, :count)

      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when outcome is missing" do
      post "/api/v1/therapy_sessions/#{session.id}/trials",
           params: trial_params.merge(outcome: nil), headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ── GET /api/v1/therapy_sessions/:session_id/trials/stream ────────────────
  describe "GET /api/v1/therapy_sessions/:therapy_session_id/trials/stream" do
    before do
      3.times do
        create(:trial,
               therapy_session: session,
               session_participant: participant,
               student_goal: goal,
               prompt_level: prompt,
               client_event_id: SecureRandom.uuid)
      end
    end

    it "returns 200 with the trial stream" do
      get "/api/v1/therapy_sessions/#{session.id}/trials/stream",
          params: { participant_id: participant.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["trials"].length).to eq(3)
    end

    it "respects the limit parameter" do
      get "/api/v1/therapy_sessions/#{session.id}/trials/stream",
          params: { participant_id: participant.id, limit: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["trials"].length).to eq(2)
    end

    it "returns 404 when the participant does not exist" do
      get "/api/v1/therapy_sessions/#{session.id}/trials/stream",
          params: { participant_id: SecureRandom.uuid }, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
