# frozen_string_literal: true

require "rails_helper"

# require_oversight_role must answer with a clean 403 (not a 500) for staff
# outside the oversight group, and let oversight roles through.
RSpec.describe "Oversight role guard", type: :request do
  let(:student) { create(:student) }

  describe "GET /api/v1/students/:id/progress_monitoring" do
    let(:path) { "/api/v1/students/#{student.id}/progress_monitoring" }

    it "returns 403 for a teacher" do
      get path, headers: teacher_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to eq("Forbidden: Oversight access required")
    end

    it "returns 200 for a Director, including internal notes" do
      create(:internal_student_note, student: student)

      get path, headers: director_headers

      expect(response).to have_http_status(:ok)
      notes = response.parsed_body.dig("data", "internal_notes")
      expect(notes).to include("count" => 1, "access_granted" => true)
    end

    it "lets a coordinator in without exposing note content" do
      create(:internal_student_note, student: student)

      get path, headers: therapy_coordinator_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "internal_notes")).to include("access_granted" => false, "notes" => nil)
    end

    it "includes session history with the teacher and trial counts" do
      teacher = create(:staff_member, role: "teacher", full_name: "Selam Tesfaye")
      session = create(:therapy_session, teacher: teacher)
      participant = create(:session_participant, therapy_session: session, student: student,
                                                 teacher_student_assignment: create(:teacher_student_assignment, student: student))
      goal = create(:student_goal, student: student)
      create_list(:trial, 2, therapy_session: session, session_participant: participant, student_goal: goal)

      get path, headers: director_headers

      expect(response).to have_http_status(:ok)
      history = response.parsed_body.dig("data", "session_history")
      expect(history["total_sessions"]).to eq(1)
      expect(history["recent_sessions"].first).to include("teacher_name" => "Selam Tesfaye", "trial_count" => 2)
    end

    it "returns 404 for an unknown student" do
      get "/api/v1/students/#{SecureRandom.uuid}/progress_monitoring", headers: director_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/reports/foundation_overview" do
    let(:path) { "/api/v1/reports/foundation_overview" }

    it "requires authentication" do
      get path
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a teacher" do
      get path, headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a Director" do
      get path, headers: director_headers
      expect(response).to have_http_status(:ok)
    end
  end
end
