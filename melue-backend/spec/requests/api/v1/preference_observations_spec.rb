# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PreferenceAssessments::Observations", type: :request do
  let(:user)        { create(:user) }
  let!(:teacher)    { create(:staff_member, user: user) }
  let(:headers)     { authenticated_headers(user) }
  let(:cycle)       { create(:assessment_cycle) }
  let!(:assessment) { create(:preference_assessment, assessment_cycle: cycle) }
  let(:item)        { create(:preference_inventory_item, name: "Swing", category: "Movement") }

  let(:base_path) do
    "/api/v1/assessment_cycles/#{cycle.id}/preference_assessment/observations"
  end

  describe "POST /observations" do
    it "records a catalogue item and returns 201" do
      expect {
        post base_path,
             params:  { context: "sensory_time", preference_inventory_item_id: item.id,
                        approached: true, duration_seconds: 120, frequency_count: 3 },
             headers: headers, as: :json
      }.to change(PreferenceObservation, :count).by(1)

      expect(response).to have_http_status(:created)
      observation = response.parsed_body["observation"]
      expect(observation).to include(
        "context"          => "sensory_time",
        "item_name"        => "Swing",
        "item_category"    => "Movement",
        "custom_item"      => false,
        "approached"       => true,
        "duration_seconds" => 120,
        "frequency_count"  => 3,
        "rank"             => 1,
        "tier"             => "highest"
      )
    end

    it "records a custom item without touching the global inventory (FR-047f)" do
      expect {
        post base_path,
             params:  { context: "play_time", custom_item_name: "Bubble wrap",
                        custom_item_category: "Sensory", duration_seconds: 45 },
             headers: headers, as: :json
      }.not_to change(PreferenceInventoryItem, :count)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["observation"]).to include(
        "item_name"     => "Bubble wrap",
        "item_category" => "Sensory",
        "custom_item"   => true
      )
    end

    it "stores per-item notes (FR-047e)" do
      post base_path,
           params:  { context: "circle_time", preference_inventory_item_id: item.id,
                      notes: "Needed a prompt to start" },
           headers: headers, as: :json

      expect(response.parsed_body.dig("observation", "notes")).to eq("Needed a prompt to start")
    end

    it "returns 422 with neither an item nor a custom name" do
      post base_path, params: { context: "sensory_time" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for an unknown assessment cycle" do
      post "/api/v1/assessment_cycles/#{SecureRandom.uuid}/preference_assessment/observations",
           params: { context: "sensory_time" }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /observations/:id" do
    let!(:observation) do
      create(:preference_observation, preference_assessment: assessment,
                                      preference_inventory_item: item,
                                      context: "sensory_time")
    end

    it "writes the accumulated timer and counter totals (FR-047b)" do
      patch "#{base_path}/#{observation.id}",
            params:  { duration_seconds: 240, frequency_count: 6 },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(observation.reload.duration_seconds).to eq(240)
      expect(observation.frequency_count).to eq(6)
    end

    it "is idempotent because totals are absolute, not deltas" do
      2.times do
        patch "#{base_path}/#{observation.id}",
              params: { duration_seconds: 90 }, headers: headers, as: :json
      end

      expect(observation.reload.duration_seconds).to eq(90)
    end

    it "re-ranks after the update" do
      slower = create(:preference_observation,
                      preference_assessment:     assessment,
                      preference_inventory_item: create(:preference_inventory_item, name: "Slide"),
                      context:                   "sensory_time",
                      duration_seconds:          10,
                      frequency_count:           1)

      patch "#{base_path}/#{observation.id}",
            params: { duration_seconds: 600, frequency_count: 20 },
            headers: headers, as: :json

      expect(observation.reload.rank).to eq(1)
      expect(slower.reload.rank).to eq(2)
    end

    it "returns 422 for a negative duration" do
      patch "#{base_path}/#{observation.id}",
            params: { duration_seconds: -5 }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for an observation belonging to another assessment" do
      other = create(:preference_observation)

      patch "#{base_path}/#{other.id}",
            params: { duration_seconds: 10 }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 once the assessment is submitted" do
      assessment.update!(status: "submitted", submitted_at: Time.current)

      patch "#{base_path}/#{observation.id}",
            params: { duration_seconds: 10 }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /observations/:id" do
    let!(:observation) do
      create(:preference_observation, :custom, preference_assessment: assessment,
                                               context: "play_time")
    end

    it "removes the observation and returns 204" do
      expect {
        delete "#{base_path}/#{observation.id}", headers: headers, as: :json
      }.to change(PreferenceObservation, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "re-ranks what remains" do
      survivor = create(:preference_observation,
                        preference_assessment:     assessment,
                        preference_inventory_item: item,
                        context:                   "play_time",
                        duration_seconds:          30)
      observation.update!(duration_seconds: 500)
      PreferenceAssessments::RankObservationsService.call(preference_assessment: assessment)
      expect(survivor.reload.rank).to eq(2)

      delete "#{base_path}/#{observation.id}", headers: headers, as: :json

      expect(survivor.reload.rank).to eq(1)
    end
  end
end
