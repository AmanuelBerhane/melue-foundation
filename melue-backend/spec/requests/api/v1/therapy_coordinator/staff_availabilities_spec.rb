# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapyCoordinator::StaffAvailabilities", type: :request do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:coordinator_headers) { authenticated_headers(coordinator_user) }

  let(:non_coordinator_user) { create(:user, :therapist) }
  let(:non_coordinator_headers) { authenticated_headers(non_coordinator_user) }

  let(:teacher) { create(:staff_member, full_name: "Teacher Alice", role: "teacher") }
  let(:block) { create(:session_block_definition) }
  let(:date) { Date.current }

  describe "GET /api/v1/therapy_coordinator/staff_availabilities" do
    let!(:unavail1) { create(:staff_availability, staff_member: teacher, unavailable_date: date, reason: "Sick leave") }
    let!(:unavail2) { create(:staff_availability, staff_member: teacher, unavailable_date: date + 1.day, reason: "Personal day") }

    context "when authorized as therapy coordinator" do
      it "returns 200 with list of staff unavailabilities" do
        get "/api/v1/therapy_coordinator/staff_availabilities", headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        ids = body.map { |a| a["id"] }
        expect(ids).to include(unavail1.id, unavail2.id)
      end

      it "filters by date" do
        get "/api/v1/therapy_coordinator/staff_availabilities",
            params: { date: date.to_s },
            headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        ids = body.map { |a| a["id"] }
        expect(ids).to include(unavail1.id)
        expect(ids).not_to include(unavail2.id)
      end

      it "works with /api/v1/staff/:staff_id/unavailability shortcut" do
        get "/api/v1/staff/#{teacher.id}/unavailability", headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        expect(body.first["teacher_id"]).to eq(teacher.id)
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        get "/api/v1/therapy_coordinator/staff_availabilities", headers: non_coordinator_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/therapy_coordinator/staff_availabilities (FR-122)" do
    context "when marking teacher unavailable with valid params" do
      it "creates a new unavailability record and returns 201" do
        post "/api/v1/therapy_coordinator/staff_availabilities",
             params: {
               teacher_id: teacher.id,
               unavailable_date: date.to_s,
               session_block_definition_id: block.id,
               reason: "Medical appointment"
             },
             headers: coordinator_headers

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["availability"]["teacher_id"]).to eq(teacher.id)
        expect(body["availability"]["reason"]).to eq("Medical appointment")
        expect(body["availability"]["session_block_definition_id"]).to eq(block.id)
        expect(body["impacted_assignments_count"]).to eq(0)
      end
    end

    context "when duplicate unavailability is submitted" do
      before do
        create(:staff_availability, staff_member: teacher, unavailable_date: date, session_block_definition: nil)
      end

      it "returns 422 with validation error" do
        post "/api/v1/therapy_coordinator/staff_availabilities",
             params: {
               teacher_id: teacher.id,
               unavailable_date: date.to_s,
               reason: "Another reason"
             },
             headers: coordinator_headers

        expect(response).to have_http_status(:unprocessable_content)
        body = response.parsed_body
        expect(body["error"]).to include("already marked unavailable")
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        post "/api/v1/therapy_coordinator/staff_availabilities",
             params: { teacher_id: teacher.id, unavailable_date: date.to_s },
             headers: non_coordinator_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/therapy_coordinator/staff_availabilities/:id" do
    let!(:unavailability) { create(:staff_availability, staff_member: teacher, unavailable_date: date) }

    context "when authorized as therapy coordinator" do
      it "deletes the unavailability record and returns 200" do
        expect {
          delete "/api/v1/therapy_coordinator/staff_availabilities/#{unavailability.id}",
                 headers: coordinator_headers
        }.to change(StaffAvailability, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for non-existent id" do
        delete "/api/v1/therapy_coordinator/staff_availabilities/#{SecureRandom.uuid}",
               headers: coordinator_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        delete "/api/v1/therapy_coordinator/staff_availabilities/#{unavailability.id}",
               headers: non_coordinator_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
