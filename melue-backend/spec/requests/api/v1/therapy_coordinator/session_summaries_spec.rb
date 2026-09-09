# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapyCoordinator::SessionSummaries", type: :request do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:coordinator_headers) { authenticated_headers(coordinator_user) }

  let(:non_coordinator_user) { create(:user, :therapist) }
  let(:non_coordinator_headers) { authenticated_headers(non_coordinator_user) }

  let(:teacher1) { create(:staff_member, full_name: "Alice Adams") }
  let(:teacher2) { create(:staff_member, full_name: "Zoe Zimmerman") }
  let(:station1) { create(:therapy_station, name: "Station Alpha") }
  let(:station2) { create(:therapy_station, name: "Station Beta") }
  let(:room1)    { create(:therapy_room, therapy_station: station1) }
  let(:room2)    { create(:therapy_room, therapy_station: station2) }

  let(:session1) { create(:therapy_session, teacher: teacher1, therapy_station: station1, therapy_room: room1) }
  let(:session2) { create(:therapy_session, teacher: teacher2, therapy_station: station2, therapy_room: room2) }
  let(:session_draft) { create(:therapy_session, teacher: teacher1, therapy_station: station1, therapy_room: room1) }

  let!(:p1) { create(:session_participant, card_position: :active, therapy_session: session1) }
  let!(:p2) { create(:session_participant, :secondary, therapy_session: session1) }
  let!(:p3) { create(:session_participant, card_position: :active, therapy_session: session2) }
  let!(:p4) { create(:session_participant, :secondary, therapy_session: session2) }
  let!(:p5) { create(:session_participant, card_position: :active, therapy_session: session_draft) }
  let!(:p6) { create(:session_participant, :secondary, therapy_session: session_draft) }

  let!(:summary1) do
    session1.update!(status: :completed, ended_at: Time.current)
    create(:session_summary, :submitted, therapy_session: session1, submitted_at: 2.days.ago)
  end

  let!(:summary2) do
    session2.update!(status: :completed, ended_at: Time.current)
    create(:session_summary, :submitted, therapy_session: session2, submitted_at: 1.day.ago)
  end

  let!(:draft_summary) do
    create(:session_summary, status: :draft, therapy_session: session_draft)
  end

  describe "GET /api/v1/therapy_coordinator/session_summaries" do
    context "when authenticated as a Therapy Coordinator" do
      it "returns 200 with list of submitted/reviewed summaries (excluding drafts by default)" do
        get "/api/v1/therapy_coordinator/session_summaries", headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to include(summary1.id, summary2.id)
        expect(ids).not_to include(draft_summary.id)

        pagination = response.parsed_body["pagination"]
        expect(pagination["total_count"]).to eq(2)
      end

      it "filters by teacher_id" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { teacher_id: teacher1.id }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary1.id ])
      end

      it "filters by station_id" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { station_id: station2.id }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary2.id ])
      end

      it "filters by room_id" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { room_id: room2.id }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary2.id ])
      end

      it "filters by student_id" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { student_id: p1.student_id }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary1.id ])
      end

      it "filters by date range" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { date_from: 36.hours.ago.iso8601 }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary2.id ])
      end

      it "sorts newest submitted summaries first by default" do
        get "/api/v1/therapy_coordinator/session_summaries", headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary2.id, summary1.id ])
      end

      it "sorts by teacher name ASC" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { sort_by: "teacher", sort_order: "asc" }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary1.id, summary2.id ])
      end

      it "sorts by teacher name DESC" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { sort_by: "teacher", sort_order: "desc" }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary2.id, summary1.id ])
      end

      it "sorts by station name ASC" do
        get "/api/v1/therapy_coordinator/session_summaries",
            params: { sort_by: "station", sort_order: "asc" }, headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body["session_summaries"].map { |s| s["id"] }
        expect(ids).to eq([ summary1.id, summary2.id ])
      end
    end

    context "when authenticated as a non-coordinator" do
      it "returns 403 Forbidden" do
        get "/api/v1/therapy_coordinator/session_summaries", headers: non_coordinator_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/therapy_coordinator/session_summaries"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/therapy_coordinator/session_summaries/:id/review" do
    context "when authenticated as a Therapy Coordinator" do
      it "marks submitted summary as reviewed" do
        patch "/api/v1/therapy_coordinator/session_summaries/#{summary1.id}/review",
              headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body["session_summary"]
        expect(json["status"]).to eq("reviewed")
        expect(json["reviewed_by_user_id"]).to eq(coordinator_user.id)
        expect(json["reviewed_at"]).to be_present
      end

      it "is idempotent on repeated review requests" do
        patch "/api/v1/therapy_coordinator/session_summaries/#{summary1.id}/review",
              headers: coordinator_headers

        expect(response).to have_http_status(:ok)

        patch "/api/v1/therapy_coordinator/session_summaries/#{summary1.id}/review",
              headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body["session_summary"]
        expect(json["status"]).to eq("reviewed")
      end

      it "returns 422 when attempting to review a draft summary" do
        patch "/api/v1/therapy_coordinator/session_summaries/#{draft_summary.id}/review",
              headers: coordinator_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when authenticated as a non-coordinator" do
      it "returns 403 Forbidden" do
        patch "/api/v1/therapy_coordinator/session_summaries/#{summary1.id}/review",
              headers: non_coordinator_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
