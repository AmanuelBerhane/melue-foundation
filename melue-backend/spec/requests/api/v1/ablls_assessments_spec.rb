# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::AbllsAssessments", type: :request do
  let(:user)     { create(:user) }
  let!(:teacher) { create(:staff_member, user: user) }
  let(:headers)  { authenticated_headers(user) }
  let(:student)  { create(:student, status: "in_assessment") }
  let(:cycle)    { create(:assessment_cycle, student: student) }

  let(:domain) { create(:ablls_domain, code: "RQ", name: "Request Domain", position: 1) }
  let!(:item1) { create(:ablls_skill_item, ablls_domain: domain, identifier: "RQ1", position: 1, description: "Skill 1") }
  let!(:item2) { create(:ablls_skill_item, ablls_domain: domain, identifier: "RQ2", position: 2, description: "Skill 2") }
  let!(:item3) { create(:ablls_skill_item, ablls_domain: domain, identifier: "RQ3", position: 3, description: "Skill 3") }

  # Ensure teacher has assignment to the student
  let!(:block_def) { create(:session_block_definition) }
  let!(:station)   { create(:therapy_station) }
  let!(:room)      { create(:therapy_room, therapy_station: station) }
  let!(:assignment) do
    create(:teacher_student_assignment,
           teacher: teacher,
           student: student,
           session_block_definition: block_def,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: Date.current)
  end

  def cycle_path(suffix = nil)
    ["/api/v1/assessment_cycles/#{cycle.id}/ablls_assessment", suffix].compact.join("/")
  end

  def assessment_path(assessment, suffix = nil)
    ["/api/v1/ablls_assessments/#{assessment.id}", suffix].compact.join("/")
  end

  # ── POST create ────────────────────────────────────────────────────────────

  describe "POST /api/v1/assessment_cycles/:id/ablls_assessment" do
    it "returns 201 and opens a draft with pre-populated responses" do
      expect { post cycle_path, headers: headers, as: :json }
        .to change(AbllsAssessment, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["ablls_assessment"]
      expect(body["assessment"]["status"]).to eq("draft")
      expect(body["assessment"]["started_at"]).to be_present
      expect(body["domains"]).to be_an(Array)
      expect(body["progress"]["total_items"]).to eq(3)
      expect(body["progress"]["completed_items"]).to eq(0)
      expect(body["score_options"]).to be_an(Array)
      expect(body["score_options"].size).to eq(4)
    end

    it "returns 200 and the same record when already started (idempotent)" do
      post cycle_path, headers: headers, as: :json
      existing_id = response.parsed_body.dig("ablls_assessment", "assessment", "id")

      expect { post cycle_path, headers: headers, as: :json }
        .not_to change(AbllsAssessment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("ablls_assessment", "assessment", "id")).to eq(existing_id)
    end

    it "returns 404 for an unknown cycle" do
      post "/api/v1/assessment_cycles/#{SecureRandom.uuid}/ablls_assessment",
           headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      post cycle_path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── GET show ───────────────────────────────────────────────────────────────

  describe "GET /api/v1/assessment_cycles/:id/ablls_assessment" do
    it "returns the full assessment payload with domains, items, and progress" do
      # Start the assessment first
      post cycle_path, headers: headers, as: :json
      assessment = AbllsAssessment.last

      # Score some items
      assessment.ablls_responses.find_by(ablls_skill_item: item1).update!(score: "2", note: "Great!")
      assessment.ablls_responses.find_by(ablls_skill_item: item2).update!(score: "0")

      get cycle_path, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["ablls_assessment"]

      # Assessment metadata
      expect(body["assessment"]["type"]).to eq("ablls")

      # Student
      expect(body["student"]["id"]).to eq(student.id)

      # Progress
      expect(body["progress"]["total_items"]).to eq(3)
      expect(body["progress"]["completed_items"]).to eq(2)
      expect(body["progress"]["unanswered_items"]).to eq(1)
      expect(body["progress"]["completion_percentage"]).to eq(67)

      # Domains
      domain_data = body["domains"].first
      expect(domain_data["code"]).to eq("RQ")
      expect(domain_data["items"].size).to eq(3)

      scored_item = domain_data["items"].find { |i| i["identifier"] == "RQ1" }
      expect(scored_item["score"]).to eq("2")
      expect(scored_item["note"]).to eq("Great!")

      # Need analysis
      expect(body["need_analysis"]).to be_present
    end

    it "returns 404 before the assessment is started" do
      get cycle_path, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # ── PATCH update_response ──────────────────────────────────────────────────

  describe "PATCH /api/v1/ablls_assessments/:id/responses/:response_id" do
    let!(:assessment) do
      post cycle_path, headers: headers, as: :json
      AbllsAssessment.last
    end

    let(:response_record) { assessment.ablls_responses.find_by(ablls_skill_item: item1) }

    it "updates a score" do
      patch assessment_path(assessment, "responses/#{response_record.id}"),
            params: { score: "1" },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("response", "score")).to eq("1")
    end

    it "updates a note without changing score" do
      response_record.update!(score: "2")

      patch assessment_path(assessment, "responses/#{response_record.id}"),
            params: { note: "New observation" },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["response"]
      expect(body["score"]).to eq("2")
      expect(body["note"]).to eq("New observation")
    end

    it "rejects invalid score" do
      patch assessment_path(assessment, "responses/#{response_record.id}"),
            params: { score: "5" },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects modification of completed assessment" do
      assessment.ablls_responses.each { |r| r.update!(score: "2") }
      assessment.update!(status: "completed", completed_at: Time.current)

      patch assessment_path(assessment, "responses/#{response_record.id}"),
            params: { score: "1" },
            headers: headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── PATCH bulk_update_responses ────────────────────────────────────────────

  describe "PATCH /api/v1/ablls_assessments/:id/responses/bulk" do
    let!(:assessment) do
      post cycle_path, headers: headers, as: :json
      AbllsAssessment.last
    end

    it "updates multiple responses transactionally" do
      patch assessment_path(assessment, "responses/bulk"),
            params: {
              responses: [
                { skill_item_id: item1.id, score: "2", note: "Independent" },
                { skill_item_id: item2.id, score: "1", note: "Gesture needed" }
              ]
            },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["responses"].size).to eq(2)

      # Verify in DB
      r1 = assessment.ablls_responses.find_by(ablls_skill_item: item1)
      r2 = assessment.ablls_responses.find_by(ablls_skill_item: item2)
      expect(r1.score).to eq("2")
      expect(r2.score).to eq("1")
    end

    it "rolls back if one response has invalid score" do
      patch assessment_path(assessment, "responses/bulk"),
            params: {
              responses: [
                { skill_item_id: item1.id, score: "2" },
                { skill_item_id: item2.id, score: "INVALID" }
              ]
            },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      # First response should NOT have been saved
      expect(assessment.ablls_responses.find_by(ablls_skill_item: item1).score).to be_nil
    end
  end

  # ── POST complete ──────────────────────────────────────────────────────────

  describe "POST /api/v1/ablls_assessments/:id/complete" do
    let!(:assessment) do
      post cycle_path, headers: headers, as: :json
      AbllsAssessment.last
    end

    context "all items scored" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "2") }
      end

      it "marks assessment as completed" do
        post assessment_path(assessment, "complete"), headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("ablls_assessment", "assessment", "status")).to eq("completed")
      end
    end

    context "unanswered items remain" do
      it "rejects completion with 422" do
        post assessment_path(assessment, "complete"), headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to match(/unanswered/)
      end
    end
  end

  # ── GET score_options ──────────────────────────────────────────────────────

  describe "GET /api/v1/ablls_assessments/score_options" do
    it "returns the score metadata" do
      get "/api/v1/ablls_assessments/score_options", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      options = response.parsed_body["score_options"]
      expect(options.size).to eq(4)
      expect(options.map { |o| o["value"] }).to eq(%w[0 1 2 not_applicable])
      expect(options.first).to include("label", "prompt", "color")
    end
  end
end
