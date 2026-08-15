# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummaries::PreviewPdfService, type: :service do
  let(:session) { create(:therapy_session) }

  describe "#call" do
    it "returns failure indicating PDF generation is not implemented" do
      result = described_class.call(session: session)

      expect(result).not_to be_success
      expect(result.error).to match(/pdf generation is not implemented/i)
    end

    it "does not mutate session status or ended_at" do
      expect {
        described_class.call(session: session)
      }.not_to change { session.reload.attributes.slice("status", "ended_at") }
    end

    it "does not create or modify a SessionSummary record" do
      expect {
        described_class.call(session: session)
      }.not_to change(SessionSummary, :count)
    end
  end
end
