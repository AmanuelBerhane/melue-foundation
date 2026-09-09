# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ProgramDirector::Dashboard", type: :request do
  describe "GET /api/v1/program_director/dashboard" do
    context "when authenticated as a Program Director" do
      let(:headers) { program_director_headers }

      before do
        create_list(:student, 2, status: "in_assessment")
        create(:student, status: "assessment_complete")
        iups = create_list(:iup, 3, status: "active")
        stations = create_list(:therapy_station, 4)

        4.times do |i|
          create(:student_goal, student: iups[0].student, iup: iups[0], therapy_station: stations[i], created_at: Time.current)
        end
      end

      it "returns 200 OK with the four dashboard metrics" do
        get "/api/v1/program_director/dashboard", headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)

        expect(data["students_in_assessment"]).to eq(2)
        expect(data["assessment_complete"]).to eq(1)
        expect(data["active_iup_plans"]).to eq(3)
        expect(data["goals_assigned_this_month"]).to eq(4)
      end
    end

    context "when authenticated as an institutional admin" do
      let(:headers) { institutional_admin_headers }

      it "allows access" do
        get "/api/v1/program_director/dashboard", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when authenticated as a Teacher" do
      let(:headers) { teacher_headers }

      it "returns 403 Forbidden" do
        get "/api/v1/program_director/dashboard", headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized or 400" do
        get "/api/v1/program_director/dashboard"
        expect(response.status).to be_in([ 400, 401, 403 ])
      end
    end
  end
end
