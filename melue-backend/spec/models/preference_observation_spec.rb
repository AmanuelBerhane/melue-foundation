# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreferenceObservation, type: :model do
  let(:assessment) { create(:preference_assessment) }

  describe "item source" do
    it "is valid with a catalogue item" do
      observation = build(:preference_observation, preference_assessment: assessment)

      expect(observation).to be_valid
    end

    it "is valid as a custom item with no catalogue item (FR-047f)" do
      observation = build(:preference_observation, :custom, preference_assessment: assessment)

      expect(observation).to be_valid
    end

    it "is invalid with neither a catalogue item nor a custom name" do
      observation = build(:preference_observation,
                          preference_assessment:     assessment,
                          preference_inventory_item: nil)

      expect(observation).not_to be_valid
      expect(observation.errors[:base])
        .to include("an inventory item or a custom item name is required")
    end

    it "is invalid with both a catalogue item and a custom name" do
      observation = build(:preference_observation,
                          preference_assessment: assessment,
                          custom_item_name:      "Improvised drum")

      expect(observation).not_to be_valid
      expect(observation.errors[:custom_item_name]).to be_present
    end

    it "rejects a custom category on a catalogue item" do
      observation = build(:preference_observation,
                          preference_assessment: assessment,
                          custom_item_category:  "Toys")

      expect(observation).not_to be_valid
      expect(observation.errors[:custom_item_category]).to be_present
    end
  end

  describe "measurements" do
    it "rejects a negative duration" do
      observation = build(:preference_observation,
                          preference_assessment: assessment,
                          duration_seconds:      -1)

      expect(observation).not_to be_valid
    end

    it "rejects a negative frequency" do
      observation = build(:preference_observation,
                          preference_assessment: assessment,
                          frequency_count:       -1)

      expect(observation).not_to be_valid
    end
  end

  describe "#item_name and #item_category" do
    it "reads through to the catalogue item" do
      item = create(:preference_inventory_item, name: "Trampoline", category: "Movement")
      observation = create(:preference_observation,
                           preference_assessment:     assessment,
                           preference_inventory_item: item)

      expect(observation.item_name).to eq("Trampoline")
      expect(observation.item_category).to eq("Movement")
      expect(observation).not_to be_custom_item
    end

    it "falls back to the custom values" do
      observation = create(:preference_observation, :custom,
                           preference_assessment: assessment,
                           custom_item_name:      "Bubble wrap",
                           custom_item_category:  "Sensory")

      expect(observation.item_name).to eq("Bubble wrap")
      expect(observation.item_category).to eq("Sensory")
      expect(observation).to be_custom_item
    end
  end

  describe "#engaged?" do
    it "is true when either the timer or the counter moved" do
      expect(build(:preference_observation, duration_seconds: 5,  frequency_count: 0)).to be_engaged
      expect(build(:preference_observation, duration_seconds: 0,  frequency_count: 3)).to be_engaged
    end

    it "is false when neither moved, even if the student approached" do
      observation = build(:preference_observation,
                          approached: true, duration_seconds: 0, frequency_count: 0)

      expect(observation).not_to be_engaged
    end
  end

  describe ".ranked" do
    it "orders by rank and puts unranked observations last" do
      unranked = create(:preference_observation, preference_assessment: assessment)
      second   = create(:preference_observation, preference_assessment: assessment)
      first    = create(:preference_observation, preference_assessment: assessment)

      second.update_column(:rank, 2)
      first.update_column(:rank, 1)

      expect(assessment.preference_observations.ranked.to_a)
        .to eq([ first, second, unranked ])
    end
  end

  describe "database constraints" do
    it "refuses a duplicate catalogue item in the same context" do
      item = create(:preference_inventory_item)
      create(:preference_observation,
             preference_assessment:     assessment,
             preference_inventory_item: item,
             context:                   "play_time")

      duplicate = build(:preference_observation,
                        preference_assessment:     assessment,
                        preference_inventory_item: item,
                        context:                   "play_time")

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same catalogue item in a different context" do
      item = create(:preference_inventory_item)
      create(:preference_observation,
             preference_assessment:     assessment,
             preference_inventory_item: item,
             context:                   "play_time")

      other_context = build(:preference_observation,
                            preference_assessment:     assessment,
                            preference_inventory_item: item,
                            context:                   "circle_time")

      expect(other_context).to be_valid
      expect { other_context.save! }.to change(described_class, :count).by(1)
    end
  end
end
