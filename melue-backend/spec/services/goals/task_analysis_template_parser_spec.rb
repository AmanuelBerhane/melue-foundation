# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::TaskAnalysisTemplateParser, type: :service do
  describe "#call" do
    context "with JSON format" do
      let(:json_content) do
        {
          task_name: "Hand Washing",
          description: "Wash hands independently using soap and water",
          domain_name: "Self-Help",
          suggested_age_range: "3-6",
          applicable_therapy_groups: [ "basic" ],
          mastery_criteria: { target_percentage: 80, consecutive_sessions: 3 },
          steps: [
            { step_number: 1, name: "Turn on water", description: "Turns on faucet handle", mastery_criteria: { prompt_level: "independent" } },
            { step_number: 2, name: "Wet hands", description: "Places hands under running water", mastery_criteria: { prompt_level: "independent" } },
            { step_number: 3, name: "Apply soap", description: "Pumps liquid soap once", mastery_criteria: { prompt_level: "independent" } }
          ]
        }.to_json
      end

      it "parses valid JSON string" do
        result = described_class.call(json_content)

        expect(result.success?).to be true
        data = result.data
        expect(data[:name]).to eq("Hand Washing")
        expect(data[:description]).to eq("Wash hands independently using soap and water")
        expect(data[:domain_name]).to eq("Self-Help")
        expect(data[:steps].size).to eq(3)
        expect(data[:steps].first[:name]).to eq("Turn on water")
        expect(data[:steps].first[:step_number]).to eq(1)
      end

      it "parses valid JSON Hash" do
        hash = JSON.parse(json_content)
        result = described_class.call(hash)

        expect(result.success?).to be true
        expect(result.data[:name]).to eq("Hand Washing")
        expect(result.data[:steps].size).to eq(3)
      end

      it "returns failure for malformed JSON" do
        result = described_class.call("{ invalid json ")
        expect(result.success?).to be false
        expect(result.error).to include("Invalid JSON format")
      end
    end

    context "with CSV format" do
      let(:csv_with_metadata) do
        <<~CSV
          task_name,Brushing Teeth
          description,Brush teeth after breakfast
          domain_name,Daily Living Skills
          suggested_age_range,4-8
          overall_mastery_criteria,80% across 3 sessions
          step_number,name,description,mastery_criteria
          1,Pick up brush,Takes toothbrush from holder,Independent
          2,Wet bristles,Holds under faucet,Independent
          3,Apply paste,Squeezes pea-sized amount,Independent
          4,Brush front,Brushes incisors for 30s,Independent
        CSV
      end

      let(:simple_csv_steps_only) do
        <<~CSV
          step_number,name,description,mastery_criteria
          1,Open door,Turns knob and pushes door,Prompt free
          2,Walk through,Steps past threshold,Prompt free
          3,Close door,Pulls door until latch clicks,Prompt free
        CSV
      end

      it "parses CSV with metadata rows and steps" do
        result = described_class.call(csv_with_metadata)

        expect(result.success?).to be true
        data = result.data
        expect(data[:name]).to eq("Brushing Teeth")
        expect(data[:description]).to eq("Brush teeth after breakfast")
        expect(data[:domain_name]).to eq("Daily Living Skills")
        expect(data[:steps].size).to eq(4)
        expect(data[:steps][0][:name]).to eq("Pick up brush")
        expect(data[:steps][0][:step_number]).to eq(1)
        expect(data[:steps][3][:name]).to eq("Brush front")
        expect(data[:steps][3][:step_number]).to eq(4)
      end

      it "parses simple CSV with step list" do
        result = described_class.call(simple_csv_steps_only)

        expect(result.success?).to be true
        data = result.data
        expect(data[:steps].size).to eq(3)
        expect(data[:steps][0][:name]).to eq("Open door")
        expect(data[:steps][1][:name]).to eq("Walk through")
        expect(data[:steps][2][:name]).to eq("Close door")
      end
    end

    context "with file object" do
      it "parses StringIO / file upload" do
        file = StringIO.new({ task_name: "Putting on Shoes", steps: [ { step_number: 1, name: "Insert foot" } ] }.to_json)
        result = described_class.call(file)

        expect(result.success?).to be true
        expect(result.data[:name]).to eq("Putting on Shoes")
        expect(result.data[:steps].size).to eq(1)
      end
    end

    context "validations and edge cases" do
      it "fails on blank input" do
        result = described_class.call("")
        expect(result.success?).to be false
        expect(result.error).to include("Template data or file is required")
      end

      it "fails when no steps are present" do
        result = described_class.call({ task_name: "No steps task", steps: [] }.to_json)
        expect(result.success?).to be false
        expect(result.error).to include("at least one step")
      end

      it "fails when steps have duplicate step numbers" do
        result = described_class.call({
          task_name: "Bad steps",
          steps: [
            { step_number: 1, name: "Step A" },
            { step_number: 1, name: "Step B" }
          ]
        }.to_json)

        expect(result.success?).to be false
        expect(result.error).to include("must be unique")
      end
    end
  end
end
