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
             params: trial_params, headers: headers, as: :json
      }.to change(Trial, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["trial"]["outcome"]).to eq("correct")
      expect(json["trial"]["prompt_label"]).to eq("FP")
    end

    it "returns 200 on duplicate client_event_id (idempotent)" do
      post "/api/v1/therapy_sessions/#{session.id}/trials",
           params: trial_params, headers: headers, as: :json

      expect {
        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: trial_params, headers: headers, as: :json
      }.not_to change(Trial, :count)

      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when outcome is missing" do
      post "/api/v1/therapy_sessions/#{session.id}/trials",
           params: trial_params.merge(outcome: nil), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when a step is provided for a standard goal" do
      step = create(:student_goal_step, student_goal: goal)

      post "/api/v1/therapy_sessions/#{session.id}/trials",
           params: trial_params.merge(student_goal_step_id: step.id),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "task analysis goals" do
      let(:ta_goal) do
        create(:student_goal, :task_analysis,
               student: participant.student,
               iup: iup,
               therapy_station: station)
      end
      let!(:step1) { create(:student_goal_step, student_goal: ta_goal, step_number: 1, name: "Turn on water") }

      let(:trial_params) do
        {
          participation_id:    participant.id,
          student_goal_id:     ta_goal.id,
          student_goal_step_id: step1.id,
          prompt_level_id:     prompt.id,
          outcome:             "correct",
          client_event_id:     SecureRandom.uuid,
          logged_at:           Time.current.iso8601
        }
      end

      it "returns 201 and logs the trial against the step" do
        expect {
          post "/api/v1/therapy_sessions/#{session.id}/trials",
               params: trial_params, headers: headers, as: :json
        }.to change(Trial, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["trial"]["student_goal_step_id"]).to eq(step1.id)
      end

      it "returns 422 when the step is missing" do
        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: trial_params.except(:student_goal_step_id),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 when the step belongs to another student goal" do
        other_goal = create(:student_goal, :task_analysis,
                            student: participant.student,
                            iup: iup,
                            therapy_station: station)
        other_step = create(:student_goal_step, student_goal: other_goal)

        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: trial_params.merge(student_goal_step_id: other_step.id),
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
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
