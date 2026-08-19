# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsResponse, type: :model do
  subject { build(:ablls_response) }

  describe "validations" do
    context "valid scores" do
      %w[0 1 2 not_applicable].each do |valid_score|
        it "accepts score '#{valid_score}'" do
          subject.score = valid_score
          expect(subject).to be_valid
        end
      end

      it "accepts nil score (unanswered)" do
        subject.score = nil
        expect(subject).to be_valid
      end
    end

    context "invalid scores" do
      %w[3 -1 n/a N/A na none invalid].each do |invalid_score|
        it "rejects score '#{invalid_score}'" do
          subject.score = invalid_score
          expect(subject).not_to be_valid
          expect(subject.errors[:score]).to include("must be 0, 1, 2, or N/A")
        end
      end
    end

    context "uniqueness" do
      it "prevents duplicate responses for the same assessment and skill item" do
        existing = create(:ablls_response)
        duplicate = build(:ablls_response,
                          ablls_assessment: existing.ablls_assessment,
                          ablls_skill_item: existing.ablls_skill_item)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:ablls_skill_item_id]).to include("already has a response in this assessment")
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:ablls_assessment) }
    it { is_expected.to belong_to(:ablls_skill_item) }
  end

  describe "scopes" do
    let(:assessment) { create(:ablls_assessment) }
    let(:domain) { create(:ablls_domain, code: "SC") }
    let(:item1) { create(:ablls_skill_item, ablls_domain: domain, identifier: "SC1") }
    let(:item2) { create(:ablls_skill_item, ablls_domain: domain, identifier: "SC2") }
    let(:item3) { create(:ablls_skill_item, ablls_domain: domain, identifier: "SC3") }

    let!(:scored_response) { create(:ablls_response, :score_2, ablls_assessment: assessment, ablls_skill_item: item1) }
    let!(:unanswered_response) { create(:ablls_response, ablls_assessment: assessment, ablls_skill_item: item2) }
    let!(:need_response) { create(:ablls_response, :score_0, ablls_assessment: assessment, ablls_skill_item: item3) }

    it ".scored returns only responses with a score" do
      expect(AbllsResponse.scored).to include(scored_response, need_response)
      expect(AbllsResponse.scored).not_to include(unanswered_response)
    end

    it ".unanswered returns only responses without a score" do
      expect(AbllsResponse.unanswered).to include(unanswered_response)
      expect(AbllsResponse.unanswered).not_to include(scored_response)
    end

    it ".needs returns only responses with score 0 or 1" do
      expect(AbllsResponse.needs).to include(need_response)
      expect(AbllsResponse.needs).not_to include(scored_response, unanswered_response)
    end
  end

  describe "#completed?" do
    it "returns true when score is present" do
      subject.score = "0"
      expect(subject.completed?).to be true
    end

    it "returns true for N/A" do
      subject.score = "not_applicable"
      expect(subject.completed?).to be true
    end

    it "returns false when score is nil" do
      subject.score = nil
      expect(subject.completed?).to be false
    end
  end

  describe "#need?" do
    it "returns true for score 0" do
      subject.score = "0"
      expect(subject.need?).to be true
    end

    it "returns true for score 1" do
      subject.score = "1"
      expect(subject.need?).to be true
    end

    it "returns false for score 2" do
      subject.score = "2"
      expect(subject.need?).to be false
    end

    it "returns false for N/A" do
      subject.score = "not_applicable"
      expect(subject.need?).to be false
    end

    it "returns false for nil" do
      subject.score = nil
      expect(subject.need?).to be false
    end
  end

  describe "notes" do
    it "allows optional notes" do
      subject.note = "Responds inconsistently when verbal prompt is provided."
      expect(subject).to be_valid
    end

    it "allows empty notes" do
      subject.note = ""
      expect(subject).to be_valid
    end

    it "allows nil notes" do
      subject.note = nil
      expect(subject).to be_valid
    end
  end
end
