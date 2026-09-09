# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummaries::SubmitService, type: :service do
  let(:session) { create(:therapy_session) }
  let!(:active_participant) { create(:session_participant, card_position: :active, therapy_session: session) }
  let!(:secondary_participant) { create(:session_participant, :secondary, therapy_session: session) }

  def call(notes = "Final notes")
    described_class.call(session: session, qualitative_notes: notes)
  end

  describe "success" do
    it "submits summary and completes the session" do
      result = call("Comprehensive final summary")

      expect(result).to be_success
      summary = result.data
      expect(summary.status).to eq("submitted")
      expect(summary.submitted_at).to be_present
      expect(summary.qualitative_notes).to eq("Comprehensive final summary")

      session.reload
      expect(session.status).to eq("completed")
      expect(session.ended_at).to be_present
    end

    it "is idempotent on repeat submit" do
      first = call("First notes")
      expect(first).to be_success
      first_submitted_at = first.data.submitted_at

      second = call("Second notes")
      expect(second).to be_success
      expect(second.data.id).to eq(first.data.id)
      expect(second.data.submitted_at).to eq(first_submitted_at)
    end
  end

  describe "transaction rollback on failure" do
    it "rolls back summary if session update fails" do
      allow(session).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(session))

      result = call("Failed submit")
      expect(result).not_to be_success

      # Summary should not be saved as submitted in DB
      expect(session.reload.session_summary).to be_nil
      expect(session.status).to eq("in_progress")
    end
  end
end
