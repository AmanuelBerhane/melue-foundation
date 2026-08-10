# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PreferenceAssessments", type: :request do
  let(:user)     { create(:user) }
  let!(:teacher) { create(:staff_member, user: user) }
  let(:headers)  { authenticated_headers(user) }
  let(:student)  { create(:student, status: "in_assessment") }
  let(:cycle)    { create(:assessment_cycle, student: student) }

  def path(suffix = nil)
    [ "/api/v1/assessment_cycles/#{cycle.id}/preference_assessment", suffix ].compact.join("/")
  end

  describe "POST .../preference_assessment" do
    it "returns 201 and opens a draft" do
      expect { post path, headers: headers, as: :json }
        .to change(PreferenceAssessment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("preference_assessment", "status")).to eq("draft")
      expect(response.parsed_body.dig("preference_assessment", "student_id")).to eq(student.id)
    end

    it "returns 200 and the same record when already started (idempotent)" do
      post path, headers: headers, as: :json
      existing_id = response.parsed_body.dig("preference_assessment", "id")

      expect { post path, headers: headers, as: :json }
        .not_to change(PreferenceAssessment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("preference_assessment", "id")).to eq(existing_id)
    end

    it "returns 404 for an unknown cycle" do
      post "/api/v1/assessment_cycles/#{SecureRandom.uuid}/preference_assessment",
           headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      post path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET .../preference_assessment" do
    it "returns the assessment with its observations so a draft can resume" do
      assessment = create(:preference_assessment, assessment_cycle: cycle)
      create(:preference_observation, preference_assessment: assessment,
                                      duration_seconds: 60, frequency_count: 2)

      get path, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["preference_assessment"]
      expect(body["contexts"]).to eq(%w[sensory_time circle_time play_time])
      expect(body["observations"].size).to eq(1)
      expect(body["observations"].first["duration_seconds"]).to eq(60)
    end

    it "returns 404 before the assessment is started" do
      get path, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET .../rankings" do
    let!(:assessment) { create(:preference_assessment, assessment_cycle: cycle) }

    before do
      [ [ "Swing", 300, 10 ], [ "Sand play", 150, 20 ], [ "Beads", 0, 0 ] ].each do |name, dur, freq|
        PreferenceAssessments::RecordObservationService.call(
          preference_assessment:        assessment,
          context:                      "sensory_time",
          preference_inventory_item_id: create(:preference_inventory_item, name: name).id,
          duration_seconds:             dur,
          frequency_count:              freq
        )
      end
    end

    it "returns the ranked list with the FR-047d fields" do
      get path("rankings"), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      rankings = response.parsed_body["rankings"]

      expect(rankings.map { |r| r["rank"] }).to eq([ 1, 2, 3 ])
      expect(rankings.map { |r| r["item_name"] }).to eq([ "Swing", "Sand play", "Beads" ])
      expect(rankings.first).to include(
        "rank"             => 1,
        "item_category"    => "Toys",
        "duration_seconds" => 300,
        "frequency_count"  => 10,
        "combined_score"   => 80.0,
        "tier"             => "highest"
      )
      expect(rankings.last["tier"]).to eq("low")
    end

    it "caps the list with limit (top preferences for the IUP summary)" do
      get path("rankings?limit=2"), headers: headers, as: :json

      expect(response.parsed_body["rankings"].size).to eq(2)
    end

    it "filters to a single context" do
      get path("rankings?context=circle_time"), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["rankings"]).to be_empty
    end

    it "returns 422 for an unknown context" do
      get path("rankings?context=lunch_time"), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST .../submit" do
    let!(:assessment) { create(:preference_assessment, assessment_cycle: cycle) }

    it "submits the assessment" do
      create(:preference_observation, preference_assessment: assessment, duration_seconds: 15)

      post path("submit"), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("preference_assessment", "status")).to eq("submitted")
      expect(assessment.reload).to be_status_submitted
    end

    it "returns 422 with no observations recorded" do
      post path("submit"), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/At least one observation/)
    end
  end
end
