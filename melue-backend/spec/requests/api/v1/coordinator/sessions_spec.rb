# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Coordinator::Sessions", type: :request do
  let(:path) { "/api/v1/coordinator/sessions/active" }

  describe "GET /api/v1/coordinator/sessions/active" do
    let(:station) { create(:therapy_station) }
    let(:room) { create(:therapy_room, therapy_station: station) }
    let(:teacher) { create(:staff_member, role: "teacher") }
    let(:session) { create(:therapy_session, teacher: teacher, therapy_station: station, therapy_room: room) }
    let(:student) { create(:student, status: "active_therapy") }
    let(:assignment) { create(:teacher_student_assignment, teacher: teacher, student: student) }
    let(:goal) { create(:student_goal, student: student, therapy_station: station) }
    let!(:other_station_goal) { create(:student_goal, student: student, iup: goal.iup) }
    let!(:participant) do
      create(:session_participant, therapy_session: session, student: student,
                                   teacher_student_assignment: assignment, current_focus_student_goal: goal)
    end

    before do
      independent = create(:prompt_level, label: "+")
      prompted = create(:prompt_level, label: "FP")
      create(:trial, therapy_session: session, session_participant: participant, student_goal: goal,
                     prompt_level: independent, prompt_label_snapshot: "+", outcome: "correct", logged_at: 2.minutes.ago)
      create(:trial, therapy_session: session, session_participant: participant, student_goal: goal,
                     prompt_level: prompted, prompt_label_snapshot: "FP", outcome: "incorrect", logged_at: 1.minute.ago)
      finished = create(:session_participant).therapy_session
      finished.update!(status: "completed", ended_at: Time.current) # not live
    end

    it "returns live sessions with participants, rooms and assigned goals" do
      get path, headers: therapy_coordinator_headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["summary"]).to include("active_sessions" => 1, "students_in_session" => 1,
                                         "rooms_in_use" => 1, "trials_logged" => 2)

      live = data["sessions"].first
      expect(live).to include("id" => session.id, "trials_logged" => 2, "incidents_count" => 0)
      expect(live["room"]).to eq("id" => room.id, "name" => room.name)
      expect(live["teacher"]).to include("full_name" => teacher.full_name)
      expect(live["block"]).to include("start_time", "end_time", "seconds_remaining")

      person = live["participants"].first
      expect(person["student"]).to include("id" => student.id, "full_name" => student.full_name)
      expect(person["goals"].map { |g| g["student_goal_id"] }).to eq([ goal.id ])

      goal_json = person["goals"].first
      expect(goal_json).to include("is_current_focus" => true, "last_prompt" => "FP", "last_outcome" => "incorrect")
      expect(goal_json["trials"]).to eq("total" => 2, "correct" => 1, "incorrect" => 1, "no_response" => 0,
                                        "independence_percent" => 50.0)
    end

    it "filters by room" do
      get path, params: { room_id: SecureRandom.uuid }, headers: therapy_coordinator_headers
      expect(response.parsed_body.dig("data", "summary", "active_sessions")).to eq(0)
    end

    it "is available to Directors" do
      get path, headers: director_headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a teacher" do
      get path, headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
