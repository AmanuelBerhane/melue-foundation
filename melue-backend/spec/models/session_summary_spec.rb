# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:therapy_session) }
    it { is_expected.to belong_to(:reviewed_by_user).class_name("User").optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }

    describe "uniqueness of therapy_session_id" do
      subject { build(:session_summary) }
      it { is_expected.to validate_uniqueness_of(:therapy_session_id).case_insensitive }
    end

    context "when reviewed" do
      let(:therapy_session) { create(:therapy_session) }

      it "is invalid without reviewed_by_user" do
        summary = build(:session_summary, status: :reviewed, reviewed_at: Time.current, reviewed_by_user: nil, therapy_session: therapy_session)
        expect(summary).not_to be_valid
        expect(summary.errors[:reviewed_by_user_id]).to include("must be present for reviewed summaries")
      end

      it "is invalid without reviewed_at" do
        user = create(:user)
        summary = build(:session_summary, status: :reviewed, reviewed_at: nil, reviewed_by_user: user, therapy_session: therapy_session)
        expect(summary).not_to be_valid
        expect(summary.errors[:reviewed_at]).to include("must be present for reviewed summaries")
      end

      it "is valid with both fields" do
        user = create(:user)
        summary = build(:session_summary, status: :reviewed, reviewed_at: Time.current, submitted_at: Time.current, reviewed_by_user: user, therapy_session: therapy_session)
        expect(summary).to be_valid
      end
    end

    context "when submitted" do
      let(:therapy_session) { create(:therapy_session) }

      it "is invalid without submitted_at" do
        summary = build(:session_summary, status: :submitted, submitted_at: nil, therapy_session: therapy_session)
        expect(summary).not_to be_valid
        expect(summary.errors[:submitted_at]).to include("must be present for submitted/reviewed summaries")
      end

      it "is valid with submitted_at" do
        summary = build(:session_summary, status: :submitted, submitted_at: Time.current, therapy_session: therapy_session)
        expect(summary).to be_valid
      end
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:status)
        .with_values(draft: "draft", submitted: "submitted", reviewed: "reviewed")
        .backed_by_column_of_type(:string)
        .with_prefix(:status)
    }
  end

  describe "scopes" do
    let!(:draft) { create(:session_summary, status: :draft) }
    let!(:submitted) { create(:session_summary, :submitted) }
    let!(:reviewed) { create(:session_summary, :reviewed) }

    it "submitted_or_reviewed scope excludes drafts" do
      results = SessionSummary.submitted_or_reviewed
      expect(results).to include(submitted, reviewed)
      expect(results).not_to include(draft)
    end
  end

  describe "dependency on therapy_session" do
    it "destroys the session summary when the therapy session is destroyed" do
      session = create(:therapy_session)
      summary = create(:session_summary, therapy_session: session)
      expect { session.destroy }.to change(SessionSummary, :count).by(-1)
    end
  end
end
