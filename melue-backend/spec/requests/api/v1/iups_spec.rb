# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Iups", type: :request do
  let(:pd_user) { create(:user) }
  let!(:pd_staff) { create(:staff_member, user: pd_user) }
  let(:headers) { authenticated_headers(pd_user) }

  # Give the user Program Director role via role_assignments
  let!(:pd_role) { Role.find_or_create_by!(name: "Program Director") }
  let!(:pd_role_assignment) { RoleAssignment.create!(user: pd_user, role: pd_role) }

  let(:student) { create(:student, status: "ready_for_iup") }
  let(:cycle) { create(:assessment_cycle, student: student, status: "reviewed") }
  let!(:form_config) { create(:form_configuration, :iup) }

  # --- CREATE ---
  describe "POST /api/v1/iups" do
    it "creates a draft IUP with form submission" do
      expect {
        post "/api/v1/iups",
             params: { student_id: student.id, assessment_cycle_id: cycle.id },
             headers: headers, as: :json
      }.to change(Iup, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json.dig("iup", "status")).to eq("draft")
      expect(json.dig("iup", "student_id")).to eq(student.id)
      expect(json.dig("iup", "form_submission", "id")).to be_present
    end

    it "rejects duplicate draft IUP for same student" do
      create(:iup, :draft, student: student)

      post "/api/v1/iups",
           params: { student_id: student.id, assessment_cycle_id: cycle.id },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 401 without a token" do
      post "/api/v1/iups",
           params: { student_id: student.id, assessment_cycle_id: cycle.id },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # --- INDEX ---
  describe "GET /api/v1/iups" do
    let!(:iup1) { create(:iup, student: student, status: "active") }
    let!(:iup2) { create(:iup, :draft, student: create(:student)) }

    it "returns paginated list of IUPs" do
      get "/api/v1/iups", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["iups"]).to be_an(Array)
      expect(json["pagination"]["total_count"]).to be >= 1
    end

    it "filters by status" do
      get "/api/v1/iups", params: { status: "active" }, headers: headers

      expect(response).to have_http_status(:ok)
      statuses = response.parsed_body["iups"].map { |i| i["status"] }
      expect(statuses).to all(eq("active"))
    end

    it "excludes soft-deleted IUPs" do
      iup1.discard
      get "/api/v1/iups", headers: headers, as: :json

      iup_ids = response.parsed_body["iups"].map { |i| i["id"] }
      expect(iup_ids).not_to include(iup1.id)
    end
  end

  # --- SHOW ---
  describe "GET /api/v1/iups/:id" do
    let(:iup) { create(:iup, student: student, status: "active") }

    it "returns IUP with goals and signatures" do
      get "/api/v1/iups/#{iup.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.dig("iup", "id")).to eq(iup.id)
      expect(json.dig("iup", "student_goals")).to be_an(Array)
      expect(json.dig("iup", "signatures")).to be_an(Array)
    end

    it "returns 404 for unknown IUP" do
      get "/api/v1/iups/#{SecureRandom.uuid}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # --- UPDATE ---
  describe "PATCH /api/v1/iups/:id" do
    let(:iup) { create(:iup, :draft, student: student) }
    let!(:form_submission) do
      FormSubmission.create!(
        submittable: iup,
        form_configuration: form_config,
        status: "draft",
        values: { "existing_field" => "value" }
      )
    end

    it "merges form values on a draft IUP" do
      patch "/api/v1/iups/#{iup.id}",
            params: { form_values: { "reinforcement" => "tokens" } },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(iup.form_submission.reload.values["reinforcement"]).to eq("tokens")
      expect(iup.form_submission.values["existing_field"]).to eq("value")
    end

    it "rejects update on a finalized IUP" do
      iup.update!(status: "active")

      patch "/api/v1/iups/#{iup.id}",
            params: { form_values: { "field" => "value" } },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("finalized")
    end
  end

  # --- DESTROY ---
  describe "DELETE /api/v1/iups/:id" do
    let!(:iup) { create(:iup, :draft, student: student) }

    it "deletes a draft IUP" do
      delete "/api/v1/iups/#{iup.id}", headers: headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Iup.find_by(id: iup.id)).to be_nil
    end

    it "rejects deleting an active IUP" do
      iup.update!(status: "active")

      delete "/api/v1/iups/#{iup.id}", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # --- VALIDATE ---
  describe "GET /api/v1/iups/:id/validate" do
    let(:iup) { create(:iup, :draft, student: student, assessment_cycle: cycle) }
    let!(:form_submission) do
      FormSubmission.create!(
        submittable: iup,
        form_configuration: form_config,
        status: "draft",
        values: {}
      )
    end

    it "returns validation result" do
      get "/api/v1/iups/#{iup.id}/validate", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("valid")
      expect(json).to have_key("errors")
    end
  end

  # --- FINALIZE ---
  describe "POST /api/v1/iups/:id/finalize" do
    let(:iup) { create(:iup, :draft, student: student, assessment_cycle: cycle) }
    let!(:form_submission) do
      FormSubmission.create!(
        submittable: iup,
        form_configuration: form_config,
        status: "draft",
        values: {}
      )
    end

    it "rejects finalization without signatures" do
      post "/api/v1/iups/#{iup.id}/finalize", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("signatures")
    end

    it "finalizes IUP and transitions student status to active_therapy (FR-066)" do
      create(:iup_signature, iup: iup, signer_role: "program_director")
      create(:iup_signature, iup: iup, signer_role: "guardian")

      allow(Iups::ValidateService).to receive(:call).with(iup: iup).and_return(
        double(success?: true, error: nil)
      )

      post "/api/v1/iups/#{iup.id}/finalize", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("iup", "status")).to eq("active")
      expect(response.parsed_body.dig("iup", "student", "status")).to eq("active_therapy")
      expect(student.reload.status).to eq("active_therapy")
    end
  end
end
