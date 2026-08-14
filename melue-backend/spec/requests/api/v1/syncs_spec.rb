require 'rails_helper'

RSpec.describe "Api::V1::Syncs", type: :request do
  let(:user) { create(:user) }
  let(:headers) { authenticated_headers(user) }

  describe "GET /api/v1/sync/pull" do
    it "returns modified records since last_synced_at" do
      student = create(:student)
      get "/api/v1/sync/pull", params: { last_synced_at: 1.day.ago.iso8601 }, headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["students"].size).to be >= 1
    end
  end

  describe "POST /api/v1/sync/push" do
    it "reconciles time and applies mutations" do
      client_time = 1.hour.ago.iso8601

      payload = {
        client_timestamp: client_time,
        mutations: [
          {
            type: "Student",
            operation: "insert",
            data: { id: SecureRandom.uuid, first_name: "John", last_name: "Doe", date_of_birth: "2015-01-01", program_type: "regular", therapy_group: "basic", guardian_name: "Parent Name", guardian_phone: "555-0124" }
          }
        ]
      }

      expect {
        post "/api/v1/sync/push", params: payload, headers: headers, as: :json
      }.to change(Student, :count).by(1)

      expect(response).to have_http_status(:ok)
    end
  end
end
