# frozen_string_literal: true

require "rails_helper"

RSpec.describe BehaviorAssessment, type: :model do
  let(:cycle) { create(:assessment_cycle) }

  describe "validations" do
    it "starts as a draft" do
      expect(create(:behavior_assessment, assessment_cycle: cycle)).to be_draft
    end

    it "allows only one assessment per cycle" do
      create(:behavior_assessment, assessment_cycle: cycle)

      duplicate = build(:behavior_assessment, assessment_cycle: cycle)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:assessment_cycle_id]).to be_present
    end

    it "rejects an unknown status" do
      assessment = build(:behavior_assessment, assessment_cycle: cycle, status: "bogus")

      expect(assessment).not_to be_valid
      expect(assessment.errors[:status]).to be_present
    end

    it "accepts every declared status" do
      described_class::STATUSES.each do |status|
        assessment = build(:behavior_assessment, assessment_cycle: cycle, status: status)
        expect(assessment.valid?).to be(true), "expected #{status} to be valid"
      end
    end
  end

  describe "status predicates" do
    it "answers draft / in_progress / submitted" do
      draft     = build(:behavior_assessment, status: "draft")
      in_prog   = build(:behavior_assessment, status: "in_progress")
      submitted = build(:behavior_assessment, status: "submitted")

      expect(draft).to be_draft
      expect(in_prog).to be_in_progress
      expect(submitted).to be_submitted
      expect(draft).not_to be_submitted
    end
  end

  describe "Discard" do
    it "excludes discarded assessments from the kept scope" do
      assessment = create(:behavior_assessment, assessment_cycle: cycle)
      assessment.discard

      expect(assessment).to be_discarded
      expect(described_class.kept).not_to include(assessment)
    end

    it "can be undiscarded" do
      assessment = create(:behavior_assessment, assessment_cycle: cycle)
      assessment.discard
      assessment.undiscard

      expect(assessment).not_to be_discarded
      expect(described_class.kept).to include(assessment)
    end
  end
end
