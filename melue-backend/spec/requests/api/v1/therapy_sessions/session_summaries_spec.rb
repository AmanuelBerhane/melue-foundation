# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapySessions::SessionSummaries", type: :request do
  let(:user)    { create(:user) }
  let(:teacher) { create(:staff_member, user: user) }
  let(:station) { create(:therapy_station) }
  let(:room)    { create(:therapy_room, therapy_station: station) }
  let(:block)   { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:headers)  { authenticated_headers(user) }

  let!(:assignment1) do
    create(:teacher_student_assignment,
           teacher: teacher, student: student1,
           session_block_definition: block,
           therapy_station: station, therapy_room: room,
           scheduled_date: Date.current)
  end

  let!(:assignment2) do
    create(:teacher_student_assignment,
           teacher: teacher, student: student2,
           session_block_definition: block,
           therapy_station: station, therapy_room: room,
           scheduled_date: Date.current)
  end

  let(:session) do
    TherapySessions::StartService.call(
      assignment: assignment1,
      staff_member: teacher
    ).data
  end

  # Create active goals so the dashboard loads cleanly with some goals
  let!(:active_goal1) { create(:student_goal, student: session.active_participant.student, therapy_station: station) }
  let!(:active_goal2) { create(:student_goal, student: session.secondary_participant.student, therapy_station: station) }

  describe "GET /api/v1/therapy_sessions/:therapy_session_id/summary" do
    context "when authenticated as the owning teacher" do
      it "returns 200 with the summary payload" do
        get "/api/v1/therapy_sessions/#{session.id}/summary", headers: headers
        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json["summary"]).to be_present
        expect(json["session"]).to be_present
        expect(json["participants"]).to be_an(Array)
        expect(json["participants"].size).to eq(2)
      end

      it "creates a draft summary when one is absent" do
        expect(session.session_summary).to be_nil

        expect {
          get "/api/v1/therapy_sessions/#{session.id}/summary", headers: headers
        }.to change(SessionSummary, :count).by(1)

        expect(session.reload.session_summary).to be_present
        expect(session.session_summary.status).to eq("draft")
      end

      it "reuses the existing draft summary when present" do
        summary = create(:session_summary, therapy_session: session, status: :draft, qualitative_notes: "custom notes")

        expect {
          get "/api/v1/therapy_sessions/#{session.id}/summary", headers: headers
        }.not_to change(SessionSummary, :count)

        expect(response.parsed_body["summary"]["id"]).to eq(summary.id)
        expect(response.parsed_body["summary"]["qualitative_notes"]).to eq("custom notes")
      end
    end

    context "when authenticated as a different teacher" do
      let(:other_user)    { create(:user) }
      let(:other_teacher) { create(:staff_member, user: other_user) }
      let(:other_headers) { authenticated_headers(other_user) }

      it "returns 403 Forbidden" do
        get "/api/v1/therapy_sessions/#{session.id}/summary", headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/therapy_sessions/#{session.id}/summary"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when session does not exist" do
      it "returns 404 Not Found" do
        get "/api/v1/therapy_sessions/#{SecureRandom.uuid}/summary", headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/therapy_sessions/:therapy_session_id/summary/draft" do
    let(:draft_params) { { qualitative_notes: "Saved observations" } }

    context "when authenticated as the owning teacher" do
      it "returns 200 and saves notes as draft" do
        patch "/api/v1/therapy_sessions/#{session.id}/summary/draft",
              params: draft_params, headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["summary"]["qualitative_notes"]).to eq("Saved observations")
        expect(response.parsed_body["summary"]["status"]).to eq("draft")
      end

      it "does not complete the session or set ended_at" do
        patch "/api/v1/therapy_sessions/#{session.id}/summary/draft",
              params: draft_params, headers: headers, as: :json

        session.reload
        expect(session.status).to eq("in_progress")
        expect(session.ended_at).to be_nil
      end

      it "returns 422 when summary is already submitted" do
        create(:session_summary, :submitted, therapy_session: session)

        patch "/api/v1/therapy_sessions/#{session.id}/summary/draft",
              params: draft_params, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to match(/this summary cannot be modified/i)
      end
    end

    context "when authenticated as a different teacher" do
      let(:other_user)    { create(:user) }
      let(:other_teacher) { create(:staff_member, user: other_user) }
      let(:other_headers) { authenticated_headers(other_user) }

      it "returns 403 Forbidden" do
        patch "/api/v1/therapy_sessions/#{session.id}/summary/draft",
              params: draft_params, headers: other_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        patch "/api/v1/therapy_sessions/#{session.id}/summary/draft",
              params: draft_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/therapy_sessions/:therapy_session_id/summary/submit" do
    let(:submit_params) { { qualitative_notes: "Final submit notes" } }

    context "when authenticated as the owning teacher" do
      it "returns 200, submits the summary, and completes the session" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: submit_params, headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body["summary"]
        expect(json["status"]).to eq("submitted")
        expect(json["submitted_at"]).to be_present
        expect(json["qualitative_notes"]).to eq("Final submit notes")

        session.reload
        expect(session.status).to eq("completed")
        expect(session.ended_at).to be_present
      end

      it "is idempotent on repeat submit calls" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: submit_params, headers: headers, as: :json

        first_submitted_at = response.parsed_body["summary"]["submitted_at"]

        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: { qualitative_notes: "Ignored repeat" }, headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["summary"]["submitted_at"]).to eq(first_submitted_at)
      end

      it "prevents subsequent trial logging after session completion" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: submit_params, headers: headers, as: :json

        prompt = create(:prompt_level, label: "+")
        post "/api/v1/therapy_sessions/#{session.id}/trials",
             params: {
               participation_id: session.active_participant.id,
               student_goal_id: active_goal1.id,
               prompt_level_id: prompt.id,
               outcome: "correct",
               client_event_id: SecureRandom.uuid,
               logged_at: Time.current.iso8601
             },
             headers: headers,
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["error"]).to match(/not in progress/i)
      end
    end

    context "when authenticated as a different teacher" do
      let(:other_user)    { create(:user) }
      let(:other_teacher) { create(:staff_member, user: other_user) }
      let(:other_headers) { authenticated_headers(other_user) }

      it "returns 403 Forbidden" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: submit_params, headers: other_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/submit",
             params: submit_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/therapy_sessions/:therapy_session_id/summary/preview_pdf" do
    context "when authenticated as the owning teacher" do
      it "returns 501 Not Implemented and does not mutate session or summary" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/preview_pdf", headers: headers

        expect(response).to have_http_status(:not_implemented)
        expect(response.parsed_body["error"]).to match(/pdf generation is not implemented/i)

        session.reload
        expect(session.status).to eq("in_progress")
        expect(session.ended_at).to be_nil
        expect(session.session_summary).to be_nil
      end
    end

    context "when authenticated as a different teacher" do
      let(:other_user)    { create(:user) }
      let(:other_teacher) { create(:staff_member, user: other_user) }
      let(:other_headers) { authenticated_headers(other_user) }

      it "returns 403 Forbidden" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/preview_pdf", headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/therapy_sessions/#{session.id}/summary/preview_pdf"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
