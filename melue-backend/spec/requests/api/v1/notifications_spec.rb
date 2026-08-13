# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Notifications", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { authenticated_headers(user) }

  # ── GET /api/v1/notifications ───────────────────────────────────────────────
  describe "GET /api/v1/notifications" do
    context "when authenticated" do
      let!(:notification1) do
        create(:notification, recipient_user_id: user.id, read_at: nil)
      end
      let!(:notification2) do
        create(:notification, recipient_user_id: user.id, read_at: 1.hour.ago)
      end
      let!(:other_notification) { create(:notification) } # belongs to another user

      it "returns 200 with the current user's notifications ordered newest first" do
        get "/api/v1/notifications", headers: headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body.map { |n| n["id"] }
        expect(ids).to include(notification1.id, notification2.id)
        expect(ids).not_to include(other_notification.id)
      end

      it "returns the expected JSON shape for each notification" do
        get "/api/v1/notifications", headers: headers

        first = response.parsed_body.find { |n| n["id"] == notification1.id }
        expect(first.keys).to match_array(%w[id type payload read read_at created_at])
        expect(first["read"]).to be false
      end

      it "returns notifications newest first" do
        older = create(:notification, recipient_user_id: user.id,
                        created_at: 2.days.ago)
        newer = create(:notification, recipient_user_id: user.id,
                        created_at: 1.day.ago)

        get "/api/v1/notifications", headers: headers

        ids = response.parsed_body.map { |n| n["id"] }
        expect(ids.index(newer.id)).to be < ids.index(older.id)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/notifications"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/notifications/:id/mark_as_read ─────────────────────────────
  describe "POST /api/v1/notifications/:id/mark_as_read" do
    context "when authenticated" do
      let!(:notification) do
        create(:notification, recipient_user_id: user.id, read_at: nil)
      end

      it "returns 204 and marks the notification as read" do
        post "/api/v1/notifications/#{notification.id}/mark_as_read",
             headers: headers

        expect(response).to have_http_status(:no_content)
        expect(notification.reload.read?).to be true
      end

      it "is idempotent — returns 204 even if already read" do
        notification.update!(read_at: 1.hour.ago)

        post "/api/v1/notifications/#{notification.id}/mark_as_read",
             headers: headers

        expect(response).to have_http_status(:no_content)
      end

      it "returns 404 when the notification belongs to another user" do
        other_notification = create(:notification)

        post "/api/v1/notifications/#{other_notification.id}/mark_as_read",
             headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a non-existent notification" do
        post "/api/v1/notifications/#{SecureRandom.uuid}/mark_as_read",
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      let!(:notification) { create(:notification) }

      it "returns 401" do
        post "/api/v1/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
