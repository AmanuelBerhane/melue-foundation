# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsAssessments::NeedAnalysisService, type: :service do
  let(:student) { create(:student, status: "in_assessment") }
  let(:cycle) { create(:assessment_cycle, student: student) }
  let(:staff) { create(:staff_member) }
  let(:assessment) { create(:ablls_assessment, assessment_cycle: cycle, staff_member: staff) }

  let(:domain_a) { create(:ablls_domain, code: "NA", name: "Domain A", position: 1) }
  let(:domain_b) { create(:ablls_domain, code: "NB", name: "Domain B", position: 2) }

  before do
    @items_a = (1..10).map do |i|
      create(:ablls_skill_item, ablls_domain: domain_a, identifier: "NA#{i}", position: i)
    end

    @items_b = (1..10).map do |i|
      create(:ablls_skill_item, ablls_domain: domain_b, identifier: "NB#{i}", position: i)
    end

    (@items_a + @items_b).each do |item|
      create(:ablls_response, ablls_assessment: assessment, ablls_skill_item: item)
    end
  end

  describe ".call" do
    context "with scored items" do
      before do
        # Domain A: 5 zeros, 3 ones, 1 two, 1 N/A = need_count 8
        scores_a = %w[0 0 0 0 0 1 1 1 2 not_applicable]
        assessment.ablls_responses.where(ablls_skill_item: @items_a).each_with_index do |r, i|
          r.update!(score: scores_a[i])
        end

        # Domain B: 2 zeros, 1 one, 5 twos, 2 N/A = need_count 3
        scores_b = %w[0 0 1 2 2 2 2 2 not_applicable not_applicable]
        assessment.ablls_responses.where(ablls_skill_item: @items_b).each_with_index do |r, i|
          r.update!(score: scores_b[i])
        end
      end

      it "calculates correct score counts per domain" do
        result = described_class.call(ablls_assessment: assessment)
        domains = result.data[:domains]

        domain_a_analysis = domains.find { |d| d[:domain_code] == "NA" }
        expect(domain_a_analysis[:score_0_count]).to eq(5)
        expect(domain_a_analysis[:score_1_count]).to eq(3)
        expect(domain_a_analysis[:score_2_count]).to eq(1)
        expect(domain_a_analysis[:not_applicable_count]).to eq(1)
        expect(domain_a_analysis[:need_count]).to eq(8)
      end

      it "ranks domains by need_count descending" do
        result = described_class.call(ablls_assessment: assessment)
        domains = result.data[:domains]

        expect(domains.first[:domain_code]).to eq("NA")
        expect(domains.first[:need_count]).to eq(8)
        expect(domains.last[:domain_code]).to eq("NB")
        expect(domains.last[:need_count]).to eq(3)
      end
    end

    context "N/A does not count as a need" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "not_applicable") }
      end

      it "reports zero needs for all-N/A assessment" do
        result = described_class.call(ablls_assessment: assessment)
        domains = result.data[:domains]

        domains.each do |d|
          expect(d[:need_count]).to eq(0)
        end
      end
    end

    context "unanswered items do not count as needs" do
      it "excludes unscored domains from the ranking" do
        result = described_class.call(ablls_assessment: assessment)
        # All items are unanswered (nil score)
        expect(result.data[:domains]).to be_empty
      end
    end

    context "empty assessment" do
      let(:empty_assessment) { create(:ablls_assessment) }

      it "returns empty domains array" do
        result = described_class.call(ablls_assessment: empty_assessment)
        expect(result.data[:domains]).to be_empty
      end
    end

    context "all score 2 (no needs)" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "2") }
      end

      it "reports zero needs for all domains" do
        result = described_class.call(ablls_assessment: assessment)
        domains = result.data[:domains]

        domains.each do |d|
          expect(d[:need_count]).to eq(0)
          expect(d[:score_2_count]).to be > 0
        end
      end
    end

    context "domain with no answered items is not ranked" do
      before do
        # Only score Domain A items
        assessment.ablls_responses.where(ablls_skill_item: @items_a).each do |r|
          r.update!(score: "0")
        end
        # Domain B items remain unanswered
      end

      it "does not include unscored Domain B in ranking" do
        result = described_class.call(ablls_assessment: assessment)
        domain_codes = result.data[:domains].map { |d| d[:domain_code] }

        expect(domain_codes).to include("NA")
        expect(domain_codes).not_to include("NB")
      end
    end
  end
end
