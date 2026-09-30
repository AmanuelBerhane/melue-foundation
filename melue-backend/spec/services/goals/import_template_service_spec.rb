# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ImportTemplateService, type: :service do
  let!(:domain) { create(:goal_domain, name: "Daily Living Skills") }
  let(:director) { create(:user) }

  before do
    create(:staff_member, :program_director, user: director)
  end

  describe "#call" do
    let(:valid_json_payload) do
      {
        task_name: "Hand Washing Protocol",
        description: "Wash hands with soap and dry with towel",
        domain_name: "Daily Living Skills",
        suggested_age_range: "3-8",
        applicable_therapy_groups: [ "basic" ],
        mastery_criteria: { target_percent: 80, consecutive_sessions: 3 },
        steps: [
          { step_number: 1, name: "Turn on faucet", description: "Turns on water handle", mastery_criteria: { prompt: "independent" } },
          { step_number: 2, name: "Wet hands", description: "Puts hands in water", mastery_criteria: { prompt: "independent" } },
          { step_number: 3, name: "Apply soap", description: "Pumps soap dispenser", mastery_criteria: { prompt: "independent" } }
        ]
      }.to_json
    end

    it "creates a new Task Analysis goal with all step templates" do
      result = described_class.call(
        template_data: valid_json_payload,
        user: director
      )

      expect(result.success?).to be true
      goal = result.data
      expect(goal).to be_persisted
      expect(goal.name).to eq("Hand Washing Protocol")
      expect(goal.goal_type).to eq("task_analysis")
      expect(goal.goal_domain).to eq(domain)
      expect(goal.suggested_age_range).to eq("3-8")
      expect(goal.is_active).to be true

      expect(goal.task_analysis_step_templates.count).to eq(3)
      step1 = goal.task_analysis_step_templates.find_by(step_number: 1)
      expect(step1.name).to eq("Turn on faucet")
      expect(step1.description).to eq("Turns on water handle")
    end

    it "applies overrides if provided" do
      other_domain = create(:goal_domain, name: "Self-Help")

      result = described_class.call(
        template_data: valid_json_payload,
        user: director,
        overrides: {
          name: "Custom Hand Washing",
          goal_domain_id: other_domain.id,
          suggested_age_range: "5-10"
        }
      )

      expect(result.success?).to be true
      goal = result.data
      expect(goal.name).to eq("Custom Hand Washing")
      expect(goal.goal_domain).to eq(other_domain)
      expect(goal.suggested_age_range).to eq("5-10")
    end

    it "creates an AuditLog record" do
      expect {
        described_class.call(
          template_data: valid_json_payload,
          user: director
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("import_task_analysis_template")
      expect(log.resource_type).to eq("Goal")
      expect(log.user_id).to eq(director.id)
    end

    it "fails if template data is invalid" do
      result = described_class.call(
        template_data: "{ invalid",
        user: director
      )

      expect(result.success?).to be false
      expect(result.error).to include("Invalid JSON format")
    end
  end
end
