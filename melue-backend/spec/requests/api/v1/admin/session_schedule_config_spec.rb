require "rails_helper"

RSpec.describe "Api::V1::Admin::SessionScheduleConfig", type: :request do
  let(:admin_user) { create(:user, :institutional_admin) }
  let(:non_admin_user) { create(:user, :therapist) }
  let(:admin_headers) { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  before do
    SessionScheduleConfig.delete_all
  end

  describe "GET /api/v1/admin/session_schedule_config" do
    context "when authenticated as institutional admin" do
      it "returns the session schedule configuration" do
        get "/api/v1/admin/session_schedule_config", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["morning_start_time"]).to eq("08:00")
        expect(json["morning_end_time"]).to eq("12:00")
        expect(json["afternoon_start_time"]).to eq("13:00")
        expect(json["afternoon_end_time"]).to eq("17:00")
        expect(json["pre_therapy_duration_minutes"]).to eq(15)
        expect(json["station_1_duration_minutes"]).to eq(30)
        expect(json["station_2_duration_minutes"]).to eq(30)
        expect(json["staff_to_student_capacity"]).to eq(4)
        expect(json["draft_expiry_days"]).to eq(7)
      end

      it "always returns the same singleton instance" do
        get "/api/v1/admin/session_schedule_config", headers: admin_headers
        first_id = JSON.parse(response.body)["id"]

        get "/api/v1/admin/session_schedule_config", headers: admin_headers
        second_id = JSON.parse(response.body)["id"]

        expect(first_id).to eq(second_id)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/session_schedule_config", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/session_schedule_config"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/admin/session_schedule_config" do
    let(:valid_params) do
      {
        session_schedule_config: {
          morning_start_time: "07:00",
          morning_end_time: "13:00",
          afternoon_start_time: "14:00",
          afternoon_end_time: "19:00",
          pre_therapy_duration_minutes: 20,
          station_1_duration_minutes: 45,
          station_2_duration_minutes: 45,
          staff_to_student_capacity: 6,
          draft_expiry_days: 10
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the session schedule configuration and returns 200" do
        put "/api/v1/admin/session_schedule_config", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["morning_start_time"]).to eq("07:00")
        expect(json["morning_end_time"]).to eq("13:00")
        expect(json["afternoon_start_time"]).to eq("14:00")
        expect(json["afternoon_end_time"]).to eq("19:00")
        expect(json["pre_therapy_duration_minutes"]).to eq(20)
        expect(json["station_1_duration_minutes"]).to eq(45)
        expect(json["station_2_duration_minutes"]).to eq(45)
        expect(json["staff_to_student_capacity"]).to eq(6)
        expect(json["draft_expiry_days"]).to eq(10)

        config = SessionScheduleConfig.instance
        expect(config.morning_start_time.strftime("%H:%M")).to eq("07:00")
      end

      it "creates an audit log entry with changes" do
        SessionScheduleConfig.instance

        expect {
          put "/api/v1/admin/session_schedule_config", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("SessionScheduleConfig")
      end

      it "returns 422 when morning end time is before start time" do
        invalid_params = {
          session_schedule_config: {
            morning_start_time: "12:00",
            morning_end_time: "08:00"
          }
        }

        put "/api/v1/admin/session_schedule_config", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]["morning_end_time"]).to include("must be after morning start time")
      end

      it "returns 422 when afternoon end time is before start time" do
        invalid_params = {
          session_schedule_config: {
            afternoon_start_time: "17:00",
            afternoon_end_time: "13:00"
          }
        }

        put "/api/v1/admin/session_schedule_config", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]["afternoon_end_time"]).to include("must be after afternoon start time")
      end

      it "returns 422 when duration is negative" do
        invalid_params = {
          session_schedule_config: {
            pre_therapy_duration_minutes: -5
          }
        }

        put "/api/v1/admin/session_schedule_config", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]["pre_therapy_duration_minutes"]).to be_present
      end

      it "returns 422 when capacity is not positive" do
        invalid_params = {
          session_schedule_config: {
            staff_to_student_capacity: 0
          }
        }

        put "/api/v1/admin/session_schedule_config", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]["staff_to_student_capacity"]).to be_present
      end

      it "returns 422 when draft expiry days is not positive" do
        invalid_params = {
          session_schedule_config: {
            draft_expiry_days: 0
          }
        }

        put "/api/v1/admin/session_schedule_config", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]["draft_expiry_days"]).to be_present
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/session_schedule_config", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/session_schedule_config", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
