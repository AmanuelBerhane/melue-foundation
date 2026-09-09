# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Assessments", type: :request do
  let(:user)     { create(:user) }
  let!(:teacher) { create(:staff_member, user: user) }
  let(:headers)  { authenticated_headers(user) }

  let(:block_def) { create(:session_block_definition) }
  let(:station)   { create(:therapy_station) }
  let(:room)      { create(:therapy_room, therapy_station: station) }
  let(:student)   { create(:student, status: "in_assessment") }

  let!(:assignment) do
    create(:teacher_student_assignment,
           teacher:               teacher,
           student:               student,
           session_block_definition: block_def,
           therapy_station:          station,
           therapy_room:             room)
  end

  describe "GET /api/v1/assessments/dashboard" do
    it "returns the summary, period and student cards" do
      cycle = create(:assessment_cycle, student: student, started_on: Date.new(2026, 7, 28))
      create(:skills_assessment, assessment_cycle: cycle, status: "in_progress", progress_percent: 45)
      create(:behavior_assessment, assessment_cycle: cycle, status: "draft")

      get "/api/v1/assessments/dashboard", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body

      expect(body["summary"]).to eq(
        "total_students" => 1,
        "completed"      => 0,
        "in_progress"    => 1,
        "not_started"    => 0
      )
      expect(body["students"].first["ablls"]).to eq(
        "status"          => "in_progress",
        "progress_percent" => 45
      )
      expect(body["students"].first["behavior"]).to eq("status" => "draft")
      expect(body["assessment_period"]).to include("start" => "2026-07-28")
    end

    it "returns 401 without a token" do
      get "/api/v1/assessments/dashboard", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/assessments/launch" do
    def launch(student_id, type, request_headers: headers)
      post "/api/v1/assessments/launch",
           params:  { student_id: student_id, assessment_type: type },
           headers: request_headers, as: :json
    end

    it "creates the cycle and moves the draft to in_progress" do
      expect {
        launch(student.id, "skills")
      }.to change(AssessmentCycle, :count).by(1)
        .and change(SkillsAssessment, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body

      expect(body["assessment_type"]).to eq("skills")
      expect(body["status"]).to eq("in_progress")

      skills = SkillsAssessment.find(body["assessment_id"])
      expect(skills).to be_in_progress
      expect(skills.started_at).to be_present
    end

    it "moves an existing draft to in_progress on relaunch" do
      cycle  = create(:assessment_cycle, student: student)
      skills = create(:skills_assessment, assessment_cycle: cycle, status: "draft")

      launch(student.id, "skills")

      expect(response).to have_http_status(:ok)
      expect(skills.reload).to be_in_progress
      expect(skills.started_at).to be_present
      expect(response.parsed_body["assessment_cycle_id"]).to eq(cycle.id)
    end

    it "is forbidden for a student not assigned to the teacher" do
      stranger = create(:student, status: "in_assessment")

      launch(stranger.id, "behavior")

      expect(response).to have_http_status(:forbidden)
      expect(AssessmentCycle.where(student: stranger)).to be_empty
    end

    it "is forbidden without a token" do
      launch(student.id, "skills", request_headers: nil)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "cycle completion (FR-050)" do
    it "marks the cycle complete once skills, behaviour and preference are submitted" do
      cycle = create(:assessment_cycle, student: student)
      create(:skills_assessment, assessment_cycle: cycle, status: "submitted", progress_percent: 100)
      create(:behavior_assessment, assessment_cycle: cycle, status: "submitted")

      preference = create(:preference_assessment, assessment_cycle: cycle, status: "draft")
      create(:preference_observation, preference_assessment: preference, duration_seconds: 15)

      post "/api/v1/assessment_cycles/#{cycle.id}/preference_assessment/submit",
           headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(cycle.reload).to be_status_complete
      expect(cycle.completed_on).to eq(Date.current)
    end

    it "does not complete while any assessment is still missing or in draft" do
      cycle = create(:assessment_cycle, student: student)
      create(:skills_assessment, assessment_cycle: cycle, status: "submitted", progress_percent: 100)

      expect(cycle.reload).to be_status_in_progress
    end
  end
end
