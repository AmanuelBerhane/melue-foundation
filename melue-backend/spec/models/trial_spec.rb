# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trial, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:therapy_session) }
    it { is_expected.to belong_to(:session_participant) }
    it { is_expected.to belong_to(:student_goal) }
    it { is_expected.to belong_to(:prompt_level) }
    # student_goal_step belongs_to is tested when Module 7 task analysis is implemented
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:outcome) }
    it { is_expected.to validate_presence_of(:logged_at) }
    it { is_expected.to validate_presence_of(:prompt_label_snapshot) }
    it { is_expected.to validate_presence_of(:client_event_id) }

    it "validates uniqueness of client_event_id" do
      create(:trial, client_event_id: "abc-123")
      duplicate = build(:trial, client_event_id: "abc-123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:client_event_id]).to be_present
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:outcome)
        .with_values(correct: "correct", incorrect: "incorrect", no_response: "no_response")
        .backed_by_column_of_type(:string)
        .with_prefix(:outcome)
    }
  end

  describe "immutability" do
    it "raises an error when attempting to update a trial" do
      trial = create(:trial)
      expect { trial.update!(outcome: "incorrect") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
