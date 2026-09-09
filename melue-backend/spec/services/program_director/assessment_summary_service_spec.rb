# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgramDirector::AssessmentSummaryService, type: :service do
  let(:student) { create(:student, first_name: "Abel", middle_name: nil, last_name: "Tesfaye", status: "in_assessment") }
  let(:cycle) { create(:assessment_cycle, student: student, status: "in_progress") }
  let(:teacher) { create(:staff_member, role: "teacher") }

  describe "#call" do
    context "with ABLLS assessment data and responses" do
      let!(:domain1) { create(:ablls_domain, name: "Visual Performance", code: "VP", position: 1) }
      let!(:domain2) { create(:ablls_domain, name: "Receptive Language", code: "RL", position: 2) }

      let!(:item1) { create(:ablls_skill_item, ablls_domain: domain1, identifier: "B1", position: 1) }
      let!(:item2) { create(:ablls_skill_item, ablls_domain: domain1, identifier: "B2", position: 2) }
      let!(:item3) { create(:ablls_skill_item, ablls_domain: domain2, identifier: "C1", position: 1) }

      let!(:ablls) { create(:ablls_assessment, assessment_cycle: cycle, staff_member: teacher, status: "in_progress") }

      before do
        # Domain 1 (VP): item1 score=2 (mastered), item2 score=2 (mastered) -> 100% (Strength)
        create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item1, score: "2")
        create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item2, score: "2")

        # Domain 2 (RL): item3 score=0 (need) -> 0% (Need)
        create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item3, score: "0")
      end

      it "returns structured summary report data with strengths and areas of need" do
        result = described_class.call(assessment_cycle_id: cycle.id)

        expect(result).to be_success
        data = result.data

        expect(data[:student][:id]).to eq(student.id)
        expect(data[:student][:name]).to eq("Abel Tesfaye")
        expect(data[:assessment][:id]).to eq(cycle.id)

        # Skills section
        expect(data[:skills][:status]).to eq("in_progress")
        expect(data[:skills][:domains].size).to eq(2)

        # Strengths: VP with 100%
        vp_strength = data[:strengths].find { |s| s[:domain_code] == "VP" }
        expect(vp_strength).to be_present
        expect(vp_strength[:percentage]).to eq(100)

        # Areas of need: RL with score_0 = 1, need_count = 1
        rl_need = data[:areas_of_need].find { |n| n[:domain_code] == "RL" }
        expect(rl_need).to be_present
        expect(rl_need[:score_0]).to eq(1)
        expect(rl_need[:need_count]).to eq(1)

        # Visualizations
        expect(data[:visualizations][:skills_radar]).to be_an(Array)
        expect(data[:visualizations][:behavior_function_summary]).to be_an(Array)
        expect(data[:visualizations][:top_preferences]).to be_an(Array)
      end
    end

    context "with Preference assessment data" do
      let!(:preference) { create(:preference_assessment, assessment_cycle: cycle, status: "submitted", submitted_at: Time.current) }
      let!(:item_bike) { create(:preference_inventory_item, name: "Bicycle", category: "Physical") }
      let!(:item_music) { create(:preference_inventory_item, name: "Music", category: "Sensory") }

      before do
        create(:preference_observation,
               preference_assessment: preference,
               preference_inventory_item: item_bike,
               rank: 1,
               tier: "highest",
               combined_score: 95.0,
               duration_seconds: 300,
               frequency_count: 5)

        create(:preference_observation,
               preference_assessment: preference,
               preference_inventory_item: item_music,
               rank: 2,
               tier: "highest",
               combined_score: 80.0,
               duration_seconds: 200,
               frequency_count: 3)
      end

      it "includes top preferences in preference summary and visualizations" do
        result = described_class.call(assessment_cycle_id: cycle.id)

        expect(result).to be_success
        data = result.data

        expect(data[:preferences][:status]).to eq("submitted")
        expect(data[:preferences][:top_preferences].size).to eq(2)
        expect(data[:preferences][:top_preferences].first[:name]).to eq("Bicycle")
        expect(data[:preferences][:top_preferences].first[:rank]).to eq(1)

        expect(data[:visualizations][:top_preferences].first).to eq({
          rank: 1,
          name: "Bicycle",
          category: "Physical"
        })
      end
    end

    context "with not_applicable scores in ABLLS" do
      let!(:domain) { create(:ablls_domain, name: "Play", code: "P", position: 1) }
      let!(:item1) { create(:ablls_skill_item, ablls_domain: domain, identifier: "P1", position: 1) }
      let!(:item2) { create(:ablls_skill_item, ablls_domain: domain, identifier: "P2", position: 2) }
      let!(:ablls) { create(:ablls_assessment, assessment_cycle: cycle, staff_member: teacher) }

      before do
        # item1 = 2 (mastered), item2 = not_applicable
        # N/A should NOT reduce score: max possible points = 2 (from item1 only), earned = 2 -> 100%
        create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item1, score: "2")
        create(:ablls_response, ablls_assessment: ablls, ablls_skill_item: item2, score: "not_applicable")
      end

      it "does not penalize percentage calculation for N/A items" do
        result = described_class.call(assessment_cycle_id: cycle.id)

        expect(result).to be_success
        play_domain = result.data[:skills][:domains].find { |d| d[:code] == "P" }
        expect(play_domain[:percentage]).to eq(100)
        expect(play_domain[:not_applicable_count]).to eq(1)
      end
    end

    context "when cycle does not exist" do
      it "returns failure" do
        result = described_class.call(assessment_cycle_id: SecureRandom.uuid)
        expect(result).to be_failure
        expect(result.error).to eq("Assessment cycle not found")
      end
    end
  end
end
