# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::IupSignatures", type: :request do
  let(:pd_user) { create(:user) }
  let!(:pd_staff) { create(:staff_member, user: pd_user) }
  let(:headers) { authenticated_headers(pd_user) }

  let!(:pd_role) { Role.find_or_create_by!(name: "Program Director") }
  let!(:pd_role_assignment) { RoleAssignment.create!(user: pd_user, role: pd_role) }

  let(:student) { create(:student) }
  let(:iup) { create(:iup, :draft, student: student) }

  describe "POST /api/v1/iups/:iup_id/signatures" do
    it "captures a program director signature on a draft IUP" do
      post "/api/v1/iups/#{iup.id}/signatures",
           params: { signer_role: "program_director" },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json.dig("signature", "signer_role")).to eq("program_director")
      expect(json.dig("signature", "signed_at")).to be_present
    end

    it "rejects signing a finalized IUP" do
      iup.update!(status: "active")

      post "/api/v1/iups/#{iup.id}/signatures",
           params: { signer_role: "program_director" },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("draft")
    end

    it "rejects invalid signer_role" do
      post "/api/v1/iups/#{iup.id}/signatures",
           params: { signer_role: "invalid_role" },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for unknown IUP" do
      post "/api/v1/iups/#{SecureRandom.uuid}/signatures",
           params: { signer_role: "program_director" },
           headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
