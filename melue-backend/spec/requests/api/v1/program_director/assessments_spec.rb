# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ProgramDirector::Assessments", type: :request do
  let(:headers) { program_director_headers }

  describe "GET /api/v1/program_director/assessments" do
    let!(:student1) { create(:student, first_name: "Abel", middle_name: nil, last_name: "Tesfaye") }
    let!(:cycle1) { create(:assessment_cycle, student: student1, status: "in_progress", started_on: 1.week.ago) }

    let!(:student2) { create(:student, first_name: "Beth", middle_name: nil, last_name: "Smith") }
    let!(:cycle2) { create(:assessment_cycle, student: student2, status: "complete", started_on: 2.weeks.ago) }

    let!(:student3) { create(:student, first_name: "Charlie", middle_name: nil, last_name: "Brown") }
    let!(:cycle3) { create(:assessment_cycle, student: student3, status: "reviewed", started_on: 3.weeks.ago) }

    it "lists assessments with pagination metadata" do
      get "/api/v1/program_director/assessments", headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["assessments"].size).to eq(3)
      expect(data["pagination"]["total_count"]).to eq(3)
      expect(data["pagination"]["current_page"]).to eq(1)

      first_item = data["assessments"].first
      expect(first_item).to have_key("student_id")
      expect(first_item).to have_key("student_name")
      expect(first_item).to have_key("assessment_id")
      expect(first_item).to have_key("status")
      expect(first_item).to have_key("assessment_progress")
      expect(first_item).to have_key("skills_assessment")
      expect(first_item).to have_key("behavior_assessment")
      expect(first_item).to have_key("preference_assessment")
    end

    it "supports status filtering" do
      get "/api/v1/program_director/assessments", params: { status: "complete" }, headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["assessments"].size).to eq(1)
      expect(data["assessments"].first["student_name"]).to eq("Beth Smith")
      expect(data["assessments"].first["status"]).to eq("complete")
    end

    it "supports pagination parameters" do
      get "/api/v1/program_director/assessments", params: { page: 1, per_page: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["assessments"].size).to eq(2)
      expect(data["pagination"]["per_page"]).to eq(2)
      expect(data["pagination"]["total_pages"]).to eq(2)
    end

    it "denies access to teachers" do
      get "/api/v1/program_director/assessments", headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/program_director/assessments/:id" do
    let(:student) { create(:student, first_name: "Abel", middle_name: nil, last_name: "Tesfaye", date_of_birth: 8.years.ago.to_date) }
    let(:cycle) { create(:assessment_cycle, student: student, status: "complete") }
    let(:teacher) { create(:staff_member, role: "teacher") }

    let!(:domain) { create(:ablls_domain, name: "Language", code: "L", position: 1) }
    let!(:item) { create(:ablls_skill_item, ablls_domain: domain, identifier: "L1", position: 1) }
    let!(:ablls) { create(:ablls_assessment, assessment_cycle: cycle, staff_member: teacher, status: "completed") }
    let!(:ablls_resp) { create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item, score: "0") }

    let!(:pref) { create(:preference_assessment, assessment_cycle: cycle, status: "submitted", submitted_at: Time.current) }
    let!(:pref_item) { create(:preference_inventory_item, name: "Bicycle", category: "Physical") }
    let!(:pref_obs) do
      create(:preference_observation,
             preference_assessment: pref,
             preference_inventory_item: pref_item,
             rank: 1,
             tier: "highest",
             combined_score: 90.0,
             duration_seconds: 120,
             frequency_count: 4)
    end

    it "returns the complete assessment review detail report" do
      get "/api/v1/program_director/assessments/#{cycle.id}", headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      # Student info
      expect(data["student"]["id"]).to eq(student.id)
      expect(data["student"]["name"]).to eq("Abel Tesfaye")
      expect(data["student"]["age"]).to eq(8)

      # Assessment info
      expect(data["assessment"]["id"]).to eq(cycle.id)
      expect(data["assessment"]["status"]).to eq("complete")
      expect(data["assessment"]["progress"]).to eq(100)

      # Skills / ABLLS
      expect(data["skills"]["status"]).to eq("completed")
      expect(data["skills"]["domains"]).to be_an(Array)
      expect(data["areas_of_need"].first["domain"]).to eq("Language")
      expect(data["areas_of_need"].first["score_0"]).to eq(1)

      # Behavior Assessment
      expect(data["behavior"]).to have_key("mass")
      expect(data["behavior"]).to have_key("fast")
      expect(data["behavior"]).to have_key("abc_summary")
      expect(data["behavior"]).to have_key("functions")

      # Preference Assessment
      expect(data["preferences"]["status"]).to eq("submitted")
      expect(data["top_preferences"].first["name"]).to eq("Bicycle")

      # Visualizations
      expect(data["visualizations"]["skills_radar"]).to be_an(Array)
      expect(data["visualizations"]["behavior_function_summary"]).to be_an(Array)
      expect(data["visualizations"]["top_preferences"]).to be_an(Array)
    end

    it "returns 404 if assessment is not found" do
      get "/api/v1/program_director/assessments/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "denies access to teachers" do
      get "/api/v1/program_director/assessments/#{cycle.id}", headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
