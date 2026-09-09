# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ProgramDirector::AssessmentPipeline", type: :request do
  describe "GET /api/v1/program_director/assessment_pipeline" do
    let(:headers) { program_director_headers }

    context "when students exist in different assessment stages" do
      let!(:student1) { create(:student, first_name: "Abel", middle_name: nil, last_name: "Tesfaye", status: "in_assessment") }
      let!(:cycle1) { create(:assessment_cycle, student: student1, status: "in_progress") }

      let!(:student2) { create(:student, first_name: "Beth", middle_name: nil, last_name: "Smith", status: "assessment_complete") }
      let!(:cycle2) { create(:assessment_cycle, student: student2, status: "complete") }

      let!(:student3) { create(:student, first_name: "Charlie", middle_name: nil, last_name: "Brown", status: "ready_for_iup") }
      let!(:cycle3) { create(:assessment_cycle, student: student3, status: "reviewed") }

      it "returns pipeline information for each student" do
        get "/api/v1/program_director/assessment_pipeline", headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        students = data["pipeline"] || data["students"]

        expect(students).to be_an(Array)
        expect(students.size).to eq(3)

        abel = students.find { |s| s["student_id"] == student1.id }
        expect(abel["student_name"]).to eq("Abel Tesfaye")
        expect(abel["status"]).to eq("in_assessment")
        expect(abel["stage"]).to eq("Assessment")

        beth = students.find { |s| s["student_id"] == student2.id }
        expect(beth["student_name"]).to eq("Beth Smith")
        expect(beth["status"]).to eq("assessment_complete")
        expect(beth["stage"]).to eq("Ready for Review")
        expect(beth["assessment_progress"]).to eq(100)

        charlie = students.find { |s| s["student_id"] == student3.id }
        expect(charlie["stage"]).to eq("Ready for IUP")
      end
    end

    context "authorization" do
      it "denies access to teachers" do
        get "/api/v1/program_director/assessment_pipeline", headers: teacher_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
