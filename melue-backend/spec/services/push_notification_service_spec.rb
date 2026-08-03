# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushNotificationService, type: :service do
  describe "#call" do
    context "when valid recipients and message details are provided" do
      it "returns a successful result" do
        service = described_class.new(
          recipient_user_ids: ["user-uuid-1", "user-uuid-2"],
          title: "Session Completed",
          body: "Session summary has been submitted for review."
        )

        result = service.call

        expect(result).to be_success
        expect(result.data[:count]).to eq(2)
      end
    end

    context "when recipients list is empty" do
      it "returns a failed result" do
        service = described_class.new(
          recipient_user_ids: [],
          title: "Title",
          body: "Body"
        )

        result = service.call

        expect(result).to be_failure
        expect(result.error).to eq("No recipients provided")
      end
    end

    context "when title or body is missing" do
      it "returns a failed result" do
        service = described_class.new(
          recipient_user_ids: ["user-uuid-1"],
          title: "",
          body: ""
        )

        result = service.call

        expect(result).to be_failure
        expect(result.error).to eq("Title and body are required")
      end
    end
  end
end
