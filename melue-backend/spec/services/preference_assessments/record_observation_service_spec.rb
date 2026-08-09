# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreferenceAssessments::RecordObservationService, type: :service do
  let(:assessment) { create(:preference_assessment) }
  let(:item)       { create(:preference_inventory_item, name: "Swing", category: "Movement") }

  def record(**overrides)
    described_class.call(**{
      preference_assessment:        assessment,
      context:                      "sensory_time",
      preference_inventory_item_id: item.id
    }.merge(overrides))
  end

  describe "catalogue items" do
    it "creates the observation" do
      result = nil
      expect { result = record(duration_seconds: 120, frequency_count: 4) }
        .to change(PreferenceObservation, :count).by(1)

      expect(result).to be_success
      expect(result.data.duration_seconds).to eq(120)
      expect(result.data.frequency_count).to eq(4)
      expect(result.data.item_name).to eq("Swing")
    end

    it "upserts rather than duplicating when the same item is recorded again" do
      record(duration_seconds: 30)

      expect { record(duration_seconds: 90) }.not_to change(PreferenceObservation, :count)

      expect(assessment.preference_observations.sole.duration_seconds).to eq(90)
    end

    it "leaves fields the caller did not send untouched" do
      record(duration_seconds: 30, notes: "Reached for it immediately")

      record(frequency_count: 2)

      observation = assessment.preference_observations.sole
      expect(observation.notes).to eq("Reached for it immediately")
      expect(observation.duration_seconds).to eq(30)
      expect(observation.frequency_count).to eq(2)
    end

    it "rejects an item that is not in the catalogue" do
      result = record(preference_inventory_item_id: SecureRandom.uuid)

      expect(result).to be_failure
      expect(result.error).to eq("Inventory item not found or inactive")
    end

    it "rejects a deactivated item" do
      retired = create(:preference_inventory_item, :inactive)

      result = record(preference_inventory_item_id: retired.id)

      expect(result).to be_failure
    end
  end

  describe "custom items (FR-047f)" do
    it "records the item on the observation without adding it to the catalogue" do
      # Create the helper's default catalogue entry up front so the expectation
      # below measures only what the service itself does.
      item
      result = nil
      expect {
        result = record(preference_inventory_item_id: nil,
                        custom_item_name:             "Bubble wrap",
                        custom_item_category:         "Sensory")
      }.not_to change(PreferenceInventoryItem, :count)

      expect(result).to be_success
      expect(result.data).to be_custom_item
      expect(result.data.item_name).to eq("Bubble wrap")
      expect(result.data.item_category).to eq("Sensory")
    end

    it "upserts a custom item by name" do
      record(preference_inventory_item_id: nil, custom_item_name: "Bubble wrap",
             duration_seconds: 10)

      expect {
        record(preference_inventory_item_id: nil, custom_item_name: "Bubble wrap",
               duration_seconds: 45)
      }.not_to change(PreferenceObservation, :count)

      expect(assessment.preference_observations.sole.duration_seconds).to eq(45)
    end

    it "requires an item or a custom name" do
      result = record(preference_inventory_item_id: nil)

      expect(result).to be_failure
      expect(result.error).to eq("An inventory item or a custom item name is required")
    end
  end

  describe "guards" do
    it "rejects an unknown context" do
      result = record(context: "lunch_time")

      expect(result).to be_failure
      expect(result.error).to include("Context must be one of")
    end

    it "refuses to write to a submitted assessment" do
      assessment.update!(status: "submitted", submitted_at: Time.current)

      result = record(duration_seconds: 10)

      expect(result).to be_failure
      expect(result.error).to eq("Preference assessment has already been submitted")
    end
  end

  it "refreshes ranks for the affected context (FR-048)" do
    other = create(:preference_inventory_item, name: "Slide")
    record(preference_inventory_item_id: other.id, duration_seconds: 10, frequency_count: 1)

    result = record(duration_seconds: 500, frequency_count: 20)

    expect(result.data.rank).to eq(1)
    expect(result.data.tier).to eq("highest")
  end
end
