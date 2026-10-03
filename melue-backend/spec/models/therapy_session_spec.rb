# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapySession, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:teacher).class_name("StaffMember") }
    it { is_expected.to belong_to(:session_block_definition) }
    it { is_expected.to belong_to(:therapy_station) }
    it { is_expected.to belong_to(:therapy_room) }
    it { is_expected.to have_many(:session_participants).dependent(:destroy) }
    it { is_expected.to have_many(:trials).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:status)
        .with_values(in_progress: "in_progress", completed: "completed")
        .backed_by_column_of_type(:string)
        .with_prefix(:status)
    }
  end

  describe "#active_participant" do
    it "returns the participant in the active card slot" do
      session     = create(:therapy_session)
      active      = create(:session_participant, therapy_session: session, card_position: :active)
      _secondary  = create(:session_participant, :secondary, therapy_session: session)

      expect(session.active_participant).to eq(active)
    end
  end

  describe "#secondary_participant" do
    it "returns the participant in the secondary card slot" do
      session    = create(:therapy_session)
      secondary  = create(:session_participant, :secondary, therapy_session: session)
      expect(session.secondary_participant).to eq(secondary)
    end
  end

  describe "completion invariant" do
    let(:session) { create(:therapy_session, status: :in_progress) }

    context "when completing a session" do
      it "is valid when session has two participants" do
        create(:session_participant, therapy_session: session, card_position: :active)
        create(:session_participant, :secondary, therapy_session: session)

        session.status = :completed
        expect(session).to be_valid
      end

      it "is valid when session has one participant (does not block single-student sessions)" do
        create(:session_participant, therapy_session: session, card_position: :active)

        session.status = :completed
        expect(session).to be_valid
      end

      it "is invalid when session has zero participants" do
        session.status = :completed
        expect(session).not_to be_valid
        expect(session.errors[:base]).to include("a session must have one or two participants")
      end
    end
  end
end
