# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummaries::ReviewService, type: :service do
  let(:reviewer) { create(:user, :clinical_staff) }
  let(:summary)  { create(:session_summary, :submitted) }

  def call(target_summary = summary)
    described_class.call(summary: target_summary, reviewed_by_user: reviewer)
  end

  describe "success" do
    it "marks a submitted summary as reviewed" do
      result = call

      expect(result).to be_success
      reviewed = result.data
      expect(reviewed.status).to eq("reviewed")
      expect(reviewed.reviewed_by_user_id).to eq(reviewer.id)
      expect(reviewed.reviewed_at).to be_present
    end

    it "is idempotent on already reviewed summaries" do
      first = call
      expect(first).to be_success

      second = call(first.data)
      expect(second).to be_success
      expect(second.data.status).to eq("reviewed")
    end
  end

  describe "failures" do
    it "fails when trying to review a draft summary" do
      draft_summary = create(:session_summary, status: :draft)
      result = call(draft_summary)

      expect(result).not_to be_success
      expect(result.error).to match(/only submitted summaries can be reviewed/i)
    end
  end
end
