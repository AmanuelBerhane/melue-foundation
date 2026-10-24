# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Admin::FormsController", type: :request do
  let(:admin_user)    { create(:user, :institutional_admin) }
  let(:admin_headers) { authenticated_headers(admin_user) }

  let(:initial_fields) do
    [
      { "id" => "f1", "type" => "Text", "label" => "Child Full Name", "section" => "Student Info", "required" => true },
      { "id" => "f2", "type" => "Date", "label" => "Date of Birth", "section" => "Student Info", "required" => true },
      { "id" => "f3", "type" => "Text", "label" => "Parent Name", "section" => "Parent Info", "required" => true }
    ]
  end

  let!(:form_config) do
    FormConfiguration.create!(
      form_type: :enrollment,
      form_name: "Enrollment Wizard",
      revision_number: 1,
      revision_date: Date.current,
      organization_name: "Melu-e Center",
      is_default: true,
      field_schema: {
        "fields" => initial_fields,
        "customSections" => ["Student Info", "Parent Info", "Medical Info"],
        "deletedSections" => [],
        "history" => [],
        "metadata" => {
          "form_id" => "FRM-ENR-001",
          "formId" => "FRM-ENR-001",
          "form_name" => "Enrollment Wizard",
          "formName" => "Enrollment Wizard",
          "organization" => "Melu-e Center",
          "organization_name" => "Melu-e Center",
          "revision" => "Rev 1.0 · #{Date.current}",
          "revision_number" => 1,
          "pages" => "Page 1 of 6"
        }
      }
    )
  end

  describe "GET /api/v1/admin/forms/:form_name" do
    it "returns the form configuration with complete header metadata" do
      get "/api/v1/admin/forms/Enrollment%20Wizard", headers: admin_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["formName"]).to eq("Enrollment Wizard")
      expect(json["formId"]).to eq("FRM-ENR-001")
      expect(json["revisionNumber"]).to eq(1)
      expect(json["organizationName"]).to eq("Melu-e Center")
      expect(json["pages"]).to eq("Page 1 of 6")
      expect(json["fields"].size).to eq(3)
      expect(json["metadata"]).to be_a(Hash)
      expect(json["metadata"]["form_id"]).to eq("FRM-ENR-001")
    end
  end

  describe "POST /api/v1/admin/forms/:form_name" do
    context "Header Persistence & Automatic Semantic Versioning" do
      it "persists updated header attributes without dropping them and increments version automatically" do
        payload = {
          form_name: "Student Enrollment Form 2026",
          formName: "Student Enrollment Form 2026",
          formId: "FRM-ENR-2026",
          form_id: "FRM-ENR-2026",
          organization: "Melu-e Specialized Academy",
          organization_name: "Melu-e Specialized Academy",
          pages: "Page 1 of 8",
          fields: initial_fields,
          customSections: ["Student Info", "Parent Info", "Medical Info"],
          metadata: {
            formId: "FRM-ENR-2026",
            formName: "Student Enrollment Form 2026",
            organization: "Melu-e Specialized Academy",
            pages: "Page 1 of 8"
          }
        }

        post "/api/v1/admin/forms/Enrollment%20Wizard", params: payload.to_json, headers: admin_headers.merge("CONTENT_TYPE" => "application/json")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # 1. Header attributes persisted
        expect(json["formName"]).to eq("Student Enrollment Form 2026")
        expect(json["formId"]).to eq("FRM-ENR-2026")
        expect(json["organizationName"]).to eq("Melu-e Specialized Academy")
        expect(json["pages"]).to eq("Page 1 of 8")

        # 2. Semantic version incremented automatically (was 1 -> now 2)
        expect(json["revisionNumber"]).to eq(2)
        expect(json["revision"]).to include("Rev 2.0")

        # 3. Snapshot created in history array
        expect(json["history"]).to be_an(Array)
        expect(json["history"].size).to eq(1)
        snapshot = json["history"].first
        expect(snapshot["revision_number"]).to eq(1)
        expect(snapshot["formName"]).to eq("Enrollment Wizard")
        expect(snapshot["formId"]).to eq("FRM-ENR-001")
        expect(snapshot["organization"]).to eq("Melu-e Center")
        expect(snapshot["fields"].size).to eq(3)

        # 4. Verified on database record
        form_config.reload
        expect(form_config.form_name).to eq("Student Enrollment Form 2026")
        expect(form_config.organization_name).to eq("Melu-e Specialized Academy")
        expect(form_config.revision_number).to eq(2)
        expect(form_config.field_schema["metadata"]["form_id"]).to eq("FRM-ENR-2026")
        expect(form_config.field_schema["metadata"]["pages"]).to eq("Page 1 of 8")
      end

      it "respects explicit user-specified revision number without auto-incrementing past it" do
        payload = {
          formName: "Enrollment Wizard",
          formId: "FRM-ENR-001",
          revision_number: 5,
          revision: "Rev 5.0 · 2026-10-24",
          fields: initial_fields,
          metadata: {
            revision_number: 5,
            revision: "Rev 5.0 · 2026-10-24"
          }
        }

        post "/api/v1/admin/forms/Enrollment%20Wizard", params: payload.to_json, headers: admin_headers.merge("CONTENT_TYPE" => "application/json")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["revisionNumber"]).to eq(5)
        expect(json["revision"]).to eq("Rev 5.0 · 2026-10-24")

        form_config.reload
        expect(form_config.revision_number).to eq(5)
      end

      it "preserves body components (fields and custom sections) across header-only edits" do
        header_only_payload = {
          form_name: "Enrollment Form Updated",
          formName: "Enrollment Form Updated",
          formId: "FRM-ENR-UPD",
          organization: "Updated Org",
          # empty fields array passed during header edit must not clear body
          fields: [],
          metadata: {
            formId: "FRM-ENR-UPD",
            formName: "Enrollment Form Updated",
            organization: "Updated Org"
          }
        }

        post "/api/v1/admin/forms/Enrollment%20Wizard", params: header_only_payload.to_json, headers: admin_headers.merge("CONTENT_TYPE" => "application/json")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Existing 3 fields must remain preserved!
        expect(json["fields"].size).to eq(3)
        expect(json["customSections"]).to include("Student Info", "Parent Info")

        form_config.reload
        expect(form_config.field_schema["fields"].size).to eq(3)
      end

      it "subsequent body edits remain loaded and become part of the new incremented version" do
        # Step 1: Edit header
        header_payload = {
          formId: "FRM-ENR-MOD",
          formName: "Enrollment Form V2",
          fields: initial_fields,
          metadata: { formId: "FRM-ENR-MOD", formName: "Enrollment Form V2" }
        }
        post "/api/v1/admin/forms/Enrollment%20Wizard", params: header_payload.to_json, headers: admin_headers.merge("CONTENT_TYPE" => "application/json")
        expect(response).to have_http_status(:ok)
        first_save = JSON.parse(response.body)
        expect(first_save["revisionNumber"]).to eq(2)

        # Step 2: Proceed to add a new body component to this form
        new_field = { "id" => "f_allergy", "type" => "Text", "label" => "Known Allergies", "section" => "Medical Info" }
        updated_fields = initial_fields + [new_field]

        body_payload = {
          formId: first_save["formId"],
          formName: first_save["formName"],
          fields: updated_fields,
          history: first_save["history"],
          metadata: first_save["metadata"]
        }
        post "/api/v1/admin/forms/Enrollment%20Wizard", params: body_payload.to_json, headers: admin_headers.merge("CONTENT_TYPE" => "application/json")

        expect(response).to have_http_status(:ok)
        second_save = JSON.parse(response.body)

        # Version increments again for the new body change (now revision 3)
        expect(second_save["revisionNumber"]).to eq(3)
        expect(second_save["fields"].size).to eq(4)
        expect(second_save["formId"]).to eq("FRM-ENR-MOD")
        expect(second_save["formName"]).to eq("Enrollment Form V2")

        # History should now have 2 snapshots
        expect(second_save["history"].size).to eq(2)
        expect(second_save["history"].first["revision_number"]).to eq(2)
        expect(second_save["history"].last["revision_number"]).to eq(1)
      end
    end
  end
end
