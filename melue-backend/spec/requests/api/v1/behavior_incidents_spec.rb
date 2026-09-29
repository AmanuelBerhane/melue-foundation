# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Behavior Incidents Modal Options API", type: :request do
  let(:user) { create(:user, :therapist) }
  let(:staff_member) { create(:staff_member, :teacher, user: user) }
  let(:student) { create(:student) }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
  end

  describe "GET /api/v1/behavior_incidents/options" do
    it "returns all dropdown options and default definitions" do
      get "/api/v1/behavior_incidents/options", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["behaviors"]).to be_an(Array)
      expect(json["frequencies"]).to be_an(Array)
      expect(json["intensities"]).to be_an(Array)
      expect(json["categories"]).to be_an(Array)
      expect(json["antecedents"]).to be_an(Array)
      expect(json["consequences"]).to be_an(Array)
      expect(json["locations"]).to be_an(Array)

      elopement = json["behaviors"].find { |b| b["name"] == "Elopement" }
      expect(elopement).to be_present
      expect(elopement["definition"]).to include("Running or wandering away")
      expect(elopement["default_category"]).to eq("safety_concerns")
    end
  end

  describe "GET /api/v1/students/:student_id/behavior_incidents/options" do
    it "returns modal options with student context" do
      get "/api/v1/students/#{student.id}/behavior_incidents/options", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["context"]["student_id"]).to eq(student.id)
      expect(json["context"]["student_name"]).to eq(student.full_name)
      expect(json["context"]["teacher"]["id"]).to eq(staff_member.id)
    end
  end
end
