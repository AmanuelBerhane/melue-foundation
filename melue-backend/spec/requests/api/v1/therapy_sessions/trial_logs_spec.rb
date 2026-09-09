# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapySessions::TrialLogs", type: :request do
  let(:user)    { create(:user) }
  let(:teacher) { create(:staff_member, user: user) }
  let(:station) { create(:therapy_station) }
  let(:room)    { create(:therapy_room, therapy_station: station) }
  let(:block)   { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:headers)  { authenticated_headers(user) }

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

  let(:active_participant) { session.active_participant }
  let(:sec_participant)    { session.secondary_participant }

  let(:active_iup)  { create(:iup, student: active_participant.student) }
  let(:active_goal) { create(:student_goal, student: active_participant.student, iup: active_iup, therapy_station: station) }
  let(:other_goal)  { create(:student_goal, student: active_participant.student, iup: active_iup, therapy_station: station) }

  describe "GET /api/v1/therapy_sessions/:therapy_session_id/participants/:participant_id/goals/:student_goal_id/trial_log" do
    let(:prompt) { create(:prompt_level, label: "+") }

    it "returns trials ordered chronologically by logged_at ASC" do
      trial2 = create(:trial, therapy_session: session, session_participant: active_participant,
                              student_goal: active_goal, prompt_level: prompt,
                              logged_at: 5.minutes.ago)
      trial1 = create(:trial, therapy_session: session, session_participant: active_participant,
                              student_goal: active_goal, prompt_level: prompt,
                              logged_at: 10.minutes.ago)
      trial3 = create(:trial, therapy_session: session, session_participant: active_participant,
                              student_goal: active_goal, prompt_level: prompt,
                              logged_at: 1.minute.ago)

      # Trial for different goal
      create(:trial, therapy_session: session, session_participant: active_participant,
                     student_goal: other_goal, prompt_level: prompt)

      # Trial for different participant
      sec_iup = create(:iup, student: sec_participant.student)
      sec_goal = create(:student_goal, student: sec_participant.student, iup: sec_iup, therapy_station: station)
      create(:trial, therapy_session: session, session_participant: sec_participant,
                     student_goal: sec_goal, prompt_level: prompt)

      get "/api/v1/therapy_sessions/#{session.id}/participants/#{active_participant.id}/goals/#{active_goal.id}/trial_log",
          headers: headers

      expect(response).to have_http_status(:ok)
      trials = response.parsed_body["trials"]
      expect(trials.size).to eq(3)
      expect(trials.map { |t| t["id"] }).to eq([ trial1.id, trial2.id, trial3.id ])
    end

    it "returns empty array when no trials exist" do
      get "/api/v1/therapy_sessions/#{session.id}/participants/#{active_participant.id}/goals/#{active_goal.id}/trial_log",
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["trials"]).to eq([])
    end

    it "returns 404 when participant is not part of the session" do
      other_participant = create(:session_participant)

      get "/api/v1/therapy_sessions/#{session.id}/participants/#{other_participant.id}/goals/#{active_goal.id}/trial_log",
          headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when goal does not belong to the participant's student" do
      foreign_goal = create(:student_goal)

      get "/api/v1/therapy_sessions/#{session.id}/participants/#{active_participant.id}/goals/#{foreign_goal.id}/trial_log",
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 403 for another teacher" do
      other_user = create(:user)
      create(:staff_member, user: other_user)
      other_headers = authenticated_headers(other_user)

      get "/api/v1/therapy_sessions/#{session.id}/participants/#{active_participant.id}/goals/#{active_goal.id}/trial_log",
          headers: other_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 for unauthenticated request" do
      get "/api/v1/therapy_sessions/#{session.id}/participants/#{active_participant.id}/goals/#{active_goal.id}/trial_log"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
