# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsAssessments::AssessmentService, type: :service do
  let(:student) { create(:student, status: "in_assessment") }
  let(:cycle) { create(:assessment_cycle, student: student) }
  let(:staff) { create(:staff_member) }

  let(:domain) { create(:ablls_domain, code: "AS", position: 1) }
  let!(:item1) { create(:ablls_skill_item, ablls_domain: domain, identifier: "AS1", position: 1) }
  let!(:item2) { create(:ablls_skill_item, ablls_domain: domain, identifier: "AS2", position: 2) }

  describe ".start" do
    it "creates a draft assessment with pre-populated responses" do
      result = described_class.start(assessment_cycle: cycle, staff_member: staff)

      expect(result).to be_success
      assessment = result.data
      expect(assessment).to be_status_draft
      expect(assessment.started_at).to be_present
      expect(assessment.ablls_responses.count).to eq(2)
      expect(assessment.ablls_responses.pluck(:score).uniq).to eq([nil])
    end

    it "is idempotent — returns existing assessment" do
      first = described_class.start(assessment_cycle: cycle, staff_member: staff)
      second = described_class.start(assessment_cycle: cycle, staff_member: staff)

      expect(first.data.id).to eq(second.data.id)
    end
  end

  describe ".save_response" do
    let!(:assessment) do
      result = described_class.start(assessment_cycle: cycle, staff_member: staff)
      result.data
    end

    it "saves a valid score" do
      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "2"
      )

      expect(result).to be_success
      expect(result.data.score).to eq("2")
    end

    it "saves N/A score" do
      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "not_applicable"
      )

      expect(result).to be_success
      expect(result.data.score).to eq("not_applicable")
    end

    it "rejects invalid score" do
      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "3"
      )

      expect(result).to be_failure
    end

    it "saves notes independently without changing score" do
      described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "1"
      )

      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        note: "New observation"
      )

      expect(result).to be_success
      expect(result.data.score).to eq("1")
      expect(result.data.note).to eq("New observation")
    end

    it "updates score without deleting note" do
      described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "1",
        note: "My note"
      )

      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "2"
      )

      expect(result).to be_success
      expect(result.data.score).to eq("2")
      expect(result.data.note).to eq("My note")
    end

    it "transitions draft to in_progress on first score" do
      expect(assessment).to be_status_draft

      described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "0"
      )

      expect(assessment.reload).to be_status_in_progress
    end

    it "rejects modification of completed assessment" do
      assessment.update!(status: "completed", completed_at: Time.current)

      result = described_class.save_response(
        ablls_assessment: assessment,
        skill_item_id: item1.id,
        score: "2"
      )

      expect(result).to be_failure
      expect(result.error).to match(/completed/)
    end
  end

  describe ".bulk_save" do
    let!(:assessment) do
      result = described_class.start(assessment_cycle: cycle, staff_member: staff)
      result.data
    end

    it "saves multiple responses transactionally" do
      result = described_class.bulk_save(
        ablls_assessment: assessment,
        responses: [
          { skill_item_id: item1.id, score: "2", note: "Independent" },
          { skill_item_id: item2.id, score: "1", note: "Needed gesture prompt" }
        ]
      )

      expect(result).to be_success
      expect(result.data.size).to eq(2)
    end

    it "rolls back all changes if one response fails" do
      result = described_class.bulk_save(
        ablls_assessment: assessment,
        responses: [
          { skill_item_id: item1.id, score: "2" },
          { skill_item_id: item2.id, score: "INVALID" }
        ]
      )

      expect(result).to be_failure
      # Verify first response was not persisted
      expect(assessment.ablls_responses.find_by(ablls_skill_item: item1).score).to be_nil
    end
  end

  describe ".complete" do
    let!(:assessment) do
      result = described_class.start(assessment_cycle: cycle, staff_member: staff)
      result.data
    end

    context "all items scored" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "2") }
      end

      it "marks assessment as completed" do
        result = described_class.complete(ablls_assessment: assessment)

        expect(result).to be_success
        expect(result.data).to be_status_completed
        expect(result.data.completed_at).to be_present
      end
    end

    context "unanswered items remain" do
      it "rejects completion" do
        result = described_class.complete(ablls_assessment: assessment)

        expect(result).to be_failure
        expect(result.error).to match(/unanswered/)
      end
    end

    context "already completed" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "2") }
        assessment.update!(status: "completed", completed_at: Time.current)
      end

      it "rejects double completion" do
        result = described_class.complete(ablls_assessment: assessment)

        expect(result).to be_failure
        expect(result.error).to match(/already completed/)
      end
    end

    context "all N/A is valid for completion" do
      before do
        assessment.ablls_responses.each { |r| r.update!(score: "not_applicable") }
      end

      it "allows completion when all items are N/A" do
        result = described_class.complete(ablls_assessment: assessment)

        expect(result).to be_success
        expect(result.data).to be_status_completed
      end
    end
  end
end
