# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsAssessment, type: :model do
  subject { build(:ablls_assessment) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }

    it "validates uniqueness of assessment_cycle_id" do
      existing = create(:ablls_assessment)
      duplicate = build(:ablls_assessment, assessment_cycle: existing.assessment_cycle)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:assessment_cycle_id]).to include("has already been taken")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:assessment_cycle) }
    it { is_expected.to belong_to(:staff_member) }
    it { is_expected.to have_many(:ablls_responses).dependent(:destroy) }
  end

  describe "status enum" do
    it "supports draft status" do
      subject.status = "draft"
      expect(subject).to be_status_draft
    end

    it "supports in_progress status" do
      subject.status = "in_progress"
      expect(subject).to be_status_in_progress
    end

    it "supports completed status" do
      subject.status = "completed"
      expect(subject).to be_status_completed
    end
  end

  describe "#modifiable?" do
    it "returns true for draft" do
      subject.status = "draft"
      expect(subject.modifiable?).to be true
    end

    it "returns true for in_progress" do
      subject.status = "in_progress"
      expect(subject.modifiable?).to be true
    end

    it "returns false for completed" do
      subject.status = "completed"
      expect(subject.modifiable?).to be false
    end
  end

  describe "#student delegation" do
    it "delegates student to assessment_cycle" do
      assessment = create(:ablls_assessment)
      expect(assessment.student).to eq(assessment.assessment_cycle.student)
    end
  end
end
