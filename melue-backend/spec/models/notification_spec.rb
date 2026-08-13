# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  subject(:notification) { build(:notification) }

  # ── Validations ─────────────────────────────────────────────────────────────
  describe "validations" do
    it { is_expected.to be_valid }

    it "is invalid without a type" do
      notification.type = nil
      expect(notification).not_to be_valid
      expect(notification.errors[:type]).to be_present
    end

    it "is invalid with an unknown type" do
      notification.type = "unknown_type"
      expect(notification).not_to be_valid
    end

    it "is invalid without a payload_reference" do
      notification.payload_reference = nil
      expect(notification).not_to be_valid
    end

    it "is invalid when payload_reference is not valid JSON" do
      notification.payload_reference = "not json {"
      expect(notification).not_to be_valid
      expect(notification.errors[:payload_reference]).to include("must be valid JSON")
    end

    it "is valid when payload_reference is a valid JSON string" do
      notification.payload_reference = { summary: "hello" }.to_json
      expect(notification).to be_valid
    end
  end

  # ── Scopes ───────────────────────────────────────────────────────────────────
  describe "scopes" do
    let!(:user) { create(:user) }
    let!(:unread) { create(:notification, recipient_user_id: user.id, read_at: nil) }
    let!(:read)   { create(:notification, recipient_user_id: user.id, read_at: 1.hour.ago) }
    let!(:other)  { create(:notification) }

    it ".unread returns only unread notifications" do
      expect(Notification.unread).to include(unread)
      expect(Notification.unread).not_to include(read)
    end

    it ".read returns only read notifications" do
      expect(Notification.read).to include(read)
      expect(Notification.read).not_to include(unread)
    end

    it ".for_recipient scopes to the given user" do
      scoped = Notification.for_recipient(user.id)
      expect(scoped).to include(unread, read)
      expect(scoped).not_to include(other)
    end
  end

  # ── Instance methods ─────────────────────────────────────────────────────────
  describe "#read?" do
    it "returns false when read_at is nil" do
      notification.read_at = nil
      expect(notification.read?).to be false
    end

    it "returns true when read_at is set" do
      notification.read_at = Time.current
      expect(notification.read?).to be true
    end
  end

  describe "#mark_as_read!" do
    let!(:persisted) { create(:notification, read_at: nil) }

    it "sets read_at on an unread notification" do
      persisted.mark_as_read!
      expect(persisted.reload.read_at).to be_within(2.seconds).of(Time.current)
    end

    it "is idempotent — does not change read_at if already read" do
      original_time = 1.hour.ago
      persisted.update!(read_at: original_time)
      persisted.mark_as_read!
      expect(persisted.reload.read_at).to be_within(1.second).of(original_time)
    end
  end

  describe "#payload" do
    it "parses the JSON payload_reference" do
      notification.payload_reference = { key: "value" }.to_json
      expect(notification.payload).to eq("key" => "value")
    end
  end
end
