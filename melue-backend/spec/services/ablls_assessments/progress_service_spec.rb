# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsAssessments::ProgressService, type: :service do
  let(:student) { create(:student, status: "in_assessment") }
  let(:cycle) { create(:assessment_cycle, student: student) }
  let(:staff) { create(:staff_member) }
  let(:assessment) { create(:ablls_assessment, assessment_cycle: cycle, staff_member: staff) }

  let(:domain_a) { create(:ablls_domain, code: "PA", name: "Domain A", position: 1) }
  let(:domain_b) { create(:ablls_domain, code: "PB", name: "Domain B", position: 2) }

  before do
    # Domain A: 5 items
    @items_a = (1..5).map do |i|
      create(:ablls_skill_item, ablls_domain: domain_a, identifier: "PA#{i}", position: i)
    end

    # Domain B: 5 items
    @items_b = (1..5).map do |i|
      create(:ablls_skill_item, ablls_domain: domain_b, identifier: "PB#{i}", position: i)
    end

    # Create response rows
    (@items_a + @items_b).each do |item|
      create(:ablls_response, ablls_assessment: assessment, ablls_skill_item: item)
    end
  end

  describe ".call" do
    context "with no scores" do
      it "returns 0% completion" do
        result = described_class.call(ablls_assessment: assessment)

        expect(result).to be_success
        expect(result.data[:total_items]).to eq(10)
        expect(result.data[:completed_items]).to eq(0)
        expect(result.data[:unanswered_items]).to eq(10)
        expect(result.data[:completion_percentage]).to eq(0)
      end
    end

    context "with partial scores" do
      before do
        # Score 6 out of 10 items
        assessment.ablls_responses.where(ablls_skill_item: @items_a).each do |r|
          r.update!(score: "2")
        end
        assessment.ablls_responses.find_by(ablls_skill_item: @items_b.first).update!(score: "0")
      end

      it "calculates correct completion percentage" do
        result = described_class.call(ablls_assessment: assessment)

        expect(result.data[:total_items]).to eq(10)
        expect(result.data[:completed_items]).to eq(6)
        expect(result.data[:unanswered_items]).to eq(4)
        expect(result.data[:completion_percentage]).to eq(60)
      end
    end

    context "with all items scored including N/A" do
      before do
        assessment.ablls_responses.where(ablls_skill_item: @items_a).each_with_index do |r, i|
          r.update!(score: %w[0 1 2 not_applicable 0][i])
        end
        assessment.ablls_responses.where(ablls_skill_item: @items_b).each_with_index do |r, i|
          r.update!(score: %w[2 2 1 0 not_applicable][i])
        end
      end

      it "returns 100% completion (N/A counts as completed)" do
        result = described_class.call(ablls_assessment: assessment)

        expect(result.data[:total_items]).to eq(10)
        expect(result.data[:completed_items]).to eq(10)
        expect(result.data[:unanswered_items]).to eq(0)
        expect(result.data[:na_items]).to eq(2)
        expect(result.data[:completion_percentage]).to eq(100)
      end
    end

    context "score 0 counts as completed" do
      before do
        assessment.ablls_responses.each do |r|
          r.update!(score: "0")
        end
      end

      it "treats score 0 as completed (not unanswered)" do
        result = described_class.call(ablls_assessment: assessment)

        expect(result.data[:completed_items]).to eq(10)
        expect(result.data[:unanswered_items]).to eq(0)
        expect(result.data[:completion_percentage]).to eq(100)
      end
    end

    context "domain-level progress" do
      before do
        # Domain A: 3 of 5 scored
        assessment.ablls_responses.where(ablls_skill_item: @items_a[0..2]).each do |r|
          r.update!(score: "2")
        end
      end

      it "calculates per-domain completion" do
        result = described_class.call(ablls_assessment: assessment)

        domain_a_progress = result.data[:domains].find { |d| d[:domain_code] == "PA" }
        domain_b_progress = result.data[:domains].find { |d| d[:domain_code] == "PB" }

        expect(domain_a_progress[:total_items]).to eq(5)
        expect(domain_a_progress[:completed_items]).to eq(3)
        expect(domain_a_progress[:completion_percentage]).to eq(60)

        expect(domain_b_progress[:total_items]).to eq(5)
        expect(domain_b_progress[:completed_items]).to eq(0)
        expect(domain_b_progress[:completion_percentage]).to eq(0)
      end
    end
  end
end
