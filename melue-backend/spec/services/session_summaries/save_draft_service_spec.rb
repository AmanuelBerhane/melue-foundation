# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummaries::SaveDraftService, type: :service do
  let(:session) { create(:therapy_session) }

  def call(notes = "Draft note")
    described_class.call(session: session, qualitative_notes: notes)
  end

  describe "success" do
    it "creates a draft summary when none exists" do
      expect(session.session_summary).to be_nil
      result = call("First draft")

      expect(result).to be_success
      summary = result.data
      expect(summary.qualitative_notes).to eq("First draft")
      expect(summary.status).to eq("draft")
      expect(summary.submitted_at).to be_nil
    end

    it "updates existing draft notes" do
      create(:session_summary, therapy_session: session, status: :draft, qualitative_notes: "Initial")
      result = call("Updated draft")

      expect(result).to be_success
      expect(session.reload.session_summary.qualitative_notes).to eq("Updated draft")
    end

    it "repeated draft save is safe and idempotent" do
      call("First")
      call("Second")
      expect(SessionSummary.where(therapy_session_id: session.id).count).to eq(1)
      expect(session.reload.session_summary.qualitative_notes).to eq("Second")
    end

    it "does not mutate therapy session status or ended_at" do
      call("Note")
      session.reload
      expect(session.status).to eq("in_progress")
      expect(session.ended_at).to be_nil
    end
  end

  describe "failures" do
    it "fails when the summary is already submitted" do
      create(:session_summary, :submitted, therapy_session: session)
      result = call("Try overwrite")

      expect(result).not_to be_success
      expect(result.error).to match(/this summary cannot be modified/i)
    end

    it "fails when the summary is reviewed" do
      create(:session_summary, :reviewed, therapy_session: session)
      result = call("Try overwrite")

      expect(result).not_to be_success
      expect(result.error).to match(/this summary cannot be modified/i)
    end
  end
end
