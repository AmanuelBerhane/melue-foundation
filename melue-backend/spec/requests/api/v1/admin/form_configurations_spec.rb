# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Admin::FormConfigurations", type: :request do
  let(:admin_user)       { create(:user, :institutional_admin) }
  let(:non_admin_user)   { create(:user, :therapist) }
  let(:admin_headers)    { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  let(:valid_field_schema) do
    {
      "fields" => [
        { "id" => "field_1", "type" => "text",   "label" => "Student Name" },
        { "id" => "field_2", "type" => "date",   "label" => "Date of Birth" },
        { "id" => "field_3", "type" => "number", "label" => "Age" }
      ]
    }
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/form_configurations
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/form_configurations" do
    let!(:form_configs) do
      [
        create(:form_configuration, :enrollment),
        create(:form_configuration, :iup),
        create(:form_configuration, :ablls)
      ]
    end

    context "when authenticated as institutional admin" do
      it "returns all form configurations" do
        get "/api/v1/admin/form_configurations", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/form_configurations", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/form_configurations"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/form_configurations/:id
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/form_configurations/:id" do
    let(:form_config) { create(:form_configuration, :enrollment, form_name: "Enrollment Form") }

    context "when authenticated as institutional admin" do
      it "returns the specified form configuration with field_schema" do
        get "/api/v1/admin/form_configurations/#{form_config.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(form_config.id)
        expect(json["form_name"]).to eq("Enrollment Form")
        expect(json["form_type"]).to eq("enrollment")
        expect(json).to have_key("field_schema")
      end

      it "returns 404 when form configuration not found" do
        get "/api/v1/admin/form_configurations/99999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/form_configurations/#{form_config.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/form_configurations/#{form_config.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/admin/form_configurations
  # ---------------------------------------------------------------------------
  describe "POST /api/v1/admin/form_configurations" do
    let(:valid_params) do
      {
        form_configuration: {
          form_name:    "New Enrollment Form",
          form_type:    "enrollment",
          field_schema: valid_field_schema,
          is_default:   false
        }
      }
    end

    let(:invalid_params) do
      {
        form_configuration: {
          form_name:    "",
          form_type:    "enrollment",
          field_schema: {}
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "creates a new form configuration and returns 201" do
        expect {
          post "/api/v1/admin/form_configurations", params: valid_params, headers: admin_headers, as: :json
        }.to change(FormConfiguration, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["form_name"]).to eq("New Enrollment Form")
        expect(json["form_type"]).to eq("enrollment")
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/admin/form_configurations", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("create")
        expect(audit_log.resource_type).to eq("FormConfiguration")
      end

      it "returns 422 with validation errors for invalid params" do
        post "/api/v1/admin/form_configurations", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]).to have_key("form_name")
      end

      it "returns 422 for duplicate field IDs in field_schema" do
        params = {
          form_configuration: {
            form_name:    "Duplicate IDs Form",
            form_type:    "enrollment",
            field_schema: {
              "fields" => [
                { "id" => "dup_id", "type" => "text", "label" => "Field One" },
                { "id" => "dup_id", "type" => "text", "label" => "Field Two" }
              ]
            }
          }
        }

        post "/api/v1/admin/form_configurations", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["field_schema"]).to include("contains duplicate field IDs")
      end

      it "returns 422 for unsupported field types in field_schema" do
        params = {
          form_configuration: {
            form_name:    "Bad Type Form",
            form_type:    "iup",
            field_schema: {
              "fields" => [
                { "id" => "field_1", "type" => "unsupported_type", "label" => "Bad Field" }
              ]
            }
          }
        }

        post "/api/v1/admin/form_configurations", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["field_schema"]).to include(a_string_matching(/unsupported field type/))
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/form_configurations", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/form_configurations", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/admin/form_configurations/:id
  # ---------------------------------------------------------------------------
  describe "PUT /api/v1/admin/form_configurations/:id" do
    let(:form_config) { create(:form_configuration, :enrollment, form_name: "Original Form") }

    let(:valid_params) do
      {
        form_configuration: {
          form_name:    "Updated Form",
          field_schema: valid_field_schema
        }
      }
    end

    let(:invalid_params) do
      {
        form_configuration: {
          form_name: ""
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the form configuration and returns 200" do
        put "/api/v1/admin/form_configurations/#{form_config.id}", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["form_name"]).to eq("Updated Form")

        form_config.reload
        expect(form_config.form_name).to eq("Updated Form")
      end

      it "creates an audit log entry with changes" do
        form_config_id = form_config.id

        expect {
          put "/api/v1/admin/form_configurations/#{form_config_id}", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("FormConfiguration")
      end

      it "returns 422 with validation errors for invalid params" do
        put "/api/v1/admin/form_configurations/#{form_config.id}", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/form_configurations/#{form_config.id}", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/form_configurations/#{form_config.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/admin/form_configurations/:id
  # ---------------------------------------------------------------------------
  describe "DELETE /api/v1/admin/form_configurations/:id" do
    context "when authenticated as institutional admin" do
      let(:form_config) { create(:form_configuration, :iup) }

      it "deletes the form configuration and returns 204" do
        form_config_id = form_config.id

        expect {
          delete "/api/v1/admin/form_configurations/#{form_config_id}", headers: admin_headers
        }.to change(FormConfiguration, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it "creates an audit log entry" do
        form_config_id = form_config.id

        expect {
          delete "/api/v1/admin/form_configurations/#{form_config_id}", headers: admin_headers
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("destroy")
        expect(audit_log.resource_type).to eq("FormConfiguration")
      end
    end

    context "when authenticated as non-admin" do
      let(:form_config) { create(:form_configuration, :ablls) }

      it "returns 403 Forbidden" do
        delete "/api/v1/admin/form_configurations/#{form_config.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      let(:form_config) { create(:form_configuration, :enrollment) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/admin/form_configurations/#{form_config.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/admin/form_configurations/:id/import
  # ---------------------------------------------------------------------------
  describe "POST /api/v1/admin/form_configurations/:id/import" do
    let(:form_config) { create(:form_configuration, :enrollment) }

    let(:valid_json_content) do
      {
        "fields" => [
          { "id" => "imported_1", "type" => "text",   "label" => "Imported Field 1" },
          { "id" => "imported_2", "type" => "number", "label" => "Imported Field 2" }
        ]
      }.to_json
    end

    context "when authenticated as institutional admin" do
      it "imports a valid JSON file and returns 200" do
        json_file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_json_content),
          "application/json",
          original_filename: "schema.json"
        )

        post "/api/v1/admin/form_configurations/#{form_config.id}/import",
             params: { file: json_file },
             headers: admin_headers

        expect(response).to have_http_status(:ok)
        form_config.reload
        expect(form_config.field_schema["fields"].first["id"]).to eq("imported_1")
      end

      it "creates an audit log entry for the import" do
        form_config_id = form_config.id  # pre-evaluate to avoid counting creation audit log

        json_file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_json_content),
          "application/json",
          original_filename: "schema.json"
        )

        expect {
          post "/api/v1/admin/form_configurations/#{form_config_id}/import",
               params: { file: json_file },
               headers: admin_headers
        }.to change(AuditLog, :count).by(2)  # 1 update (field_schema) + 1 import audit log

        audit_log = AuditLog.where(action: "import", resource_type: "FormConfiguration").last
        expect(audit_log).to be_present
        expect(audit_log.resource_id).to eq(form_config_id.to_s)
      end

      it "returns 415 for wrong content-type" do
        txt_file = Rack::Test::UploadedFile.new(
          StringIO.new("not json"),
          "text/plain",
          original_filename: "schema.txt"
        )

        post "/api/v1/admin/form_configurations/#{form_config.id}/import",
             params: { file: txt_file },
             headers: admin_headers

        expect(response).to have_http_status(:unsupported_media_type)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("application/json")
      end

      it "returns 422 when no file is provided" do
        post "/api/v1/admin/form_configurations/#{form_config.id}/import",
             params: {},
             headers: admin_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("File is required")
      end

      it "returns 422 for invalid JSON content" do
        invalid_file = Rack::Test::UploadedFile.new(
          StringIO.new("{ not valid json"),
          "application/json",
          original_filename: "bad.json"
        )

        post "/api/v1/admin/form_configurations/#{form_config.id}/import",
             params: { file: invalid_file },
             headers: admin_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        json_file = Rack::Test::UploadedFile.new(
          StringIO.new(valid_json_content),
          "application/json",
          original_filename: "schema.json"
        )

        post "/api/v1/admin/form_configurations/#{form_config.id}/import",
             params: { file: json_file },
             headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/form_configurations/#{form_config.id}/import", params: {}

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/form_configurations/:id/export
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/form_configurations/:id/export" do
    let(:form_config) { create(:form_configuration, :enrollment, form_name: "Export Test Form", field_schema: valid_field_schema) }

    context "when authenticated as institutional admin" do
      it "returns the field_schema as a downloadable JSON file" do
        get "/api/v1/admin/form_configurations/#{form_config.id}/export", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".json")
      end

      it "returns properly formatted JSON" do
        get "/api/v1/admin/form_configurations/#{form_config.id}/export", headers: admin_headers

        expect { JSON.parse(response.body) }.not_to raise_error
        json = JSON.parse(response.body)
        expect(json).to have_key("fields")
        expect(json["fields"].length).to eq(3)
      end

      it "creates an audit log entry for the export" do
        form_config_id = form_config.id  # pre-evaluate to avoid counting creation audit log

        expect {
          get "/api/v1/admin/form_configurations/#{form_config_id}/export", headers: admin_headers
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.where(action: "export", resource_type: "FormConfiguration").last
        expect(audit_log).to be_present
        expect(audit_log.resource_id).to eq(form_config_id.to_s)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/form_configurations/#{form_config.id}/export", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/form_configurations/#{form_config.id}/export"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
