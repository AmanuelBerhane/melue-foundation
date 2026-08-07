# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Admin::AbcDropdownOptions", type: :request do
  let(:admin_user)       { create(:user, :institutional_admin) }
  let(:non_admin_user)   { create(:user, :therapist) }
  let(:admin_headers)    { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/abc_dropdown_options
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/abc_dropdown_options" do
    let!(:options) do
      [
        create(:abc_dropdown_option, :antecedent, label: "Demand",      display_order: 1),
        create(:abc_dropdown_option, :behavior,   label: "Aggression",  display_order: 1),
        create(:abc_dropdown_option, :consequence, label: "Praise",     display_order: 1)
      ]
    end

    context "when authenticated as institutional admin" do
      it "returns all ABC dropdown options" do
        get "/api/v1/admin/abc_dropdown_options", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it "filters by category when category param is provided" do
        get "/api/v1/admin/abc_dropdown_options", params: { category: "antecedent" }, headers: admin_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["label"]).to eq("Demand")
        expect(json.first["category"]).to eq("antecedent")
      end

      it "returns options ordered by display_order within a category" do
        create(:abc_dropdown_option, :antecedent, label: "Environment", display_order: 2)
        create(:abc_dropdown_option, :antecedent, label: "Attention",   display_order: 3)

        get "/api/v1/admin/abc_dropdown_options", params: { category: "antecedent" }, headers: admin_headers

        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
        expect(json.first["display_order"]).to eq(1)
        expect(json.second["display_order"]).to eq(2)
        expect(json.third["display_order"]).to eq(3)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/abc_dropdown_options", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/abc_dropdown_options"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/abc_dropdown_options/:id
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/abc_dropdown_options/:id" do
    let(:option) { create(:abc_dropdown_option, :antecedent, label: "Demand") }

    context "when authenticated as institutional admin" do
      it "returns the specified ABC dropdown option" do
        get "/api/v1/admin/abc_dropdown_options/#{option.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(option.id)
        expect(json["label"]).to eq("Demand")
        expect(json["category"]).to eq("antecedent")
      end

      it "returns 404 when option not found" do
        get "/api/v1/admin/abc_dropdown_options/99999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/abc_dropdown_options/#{option.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/abc_dropdown_options/#{option.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/admin/abc_dropdown_options
  # ---------------------------------------------------------------------------
  describe "POST /api/v1/admin/abc_dropdown_options" do
    let(:valid_params) do
      {
        abc_dropdown_option: {
          label:         "New Antecedent",
          category:      "antecedent",
          display_order: 5,
          is_active:     true,
          is_other:      false
        }
      }
    end

    let(:invalid_params) do
      {
        abc_dropdown_option: {
          label:         "",
          category:      "antecedent",
          display_order: -1
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "creates a new ABC dropdown option and returns 201" do
        expect {
          post "/api/v1/admin/abc_dropdown_options", params: valid_params, headers: admin_headers, as: :json
        }.to change(AbcDropdownOption, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["label"]).to eq("New Antecedent")
        expect(json["category"]).to eq("antecedent")
        expect(json["display_order"]).to eq(5)
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/admin/abc_dropdown_options", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("create")
        expect(audit_log.resource_type).to eq("AbcDropdownOption")
      end

      it "returns 422 with validation errors for invalid params" do
        post "/api/v1/admin/abc_dropdown_options", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]).to have_key("label")
        expect(json["errors"]).to have_key("display_order")
      end

      it "returns 422 for invalid category enum" do
        params = {
          abc_dropdown_option: {
            label:         "Test",
            category:      "invalid_category",
            display_order: 1
          }
        }

        expect {
          post "/api/v1/admin/abc_dropdown_options", params: params, headers: admin_headers, as: :json
        }.to raise_error(ArgumentError)
      end

      it "enforces only one 'Other' option per category" do
        create(:abc_dropdown_option, :antecedent, :is_other, label: "Other Antecedent")

        params = {
          abc_dropdown_option: {
            label:         "Another Other",
            category:      "antecedent",
            display_order: 99,
            is_other:      true
          }
        }

        post "/api/v1/admin/abc_dropdown_options", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["is_other"]).to include("only one 'Other' option allowed per category")
      end

      it "allows 'Other' option in a different category" do
        create(:abc_dropdown_option, :antecedent, :is_other, label: "Other A")

        params = {
          abc_dropdown_option: {
            label:         "Other B",
            category:      "behavior",
            display_order: 99,
            is_other:      true
          }
        }

        post "/api/v1/admin/abc_dropdown_options", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:created)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/abc_dropdown_options", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/abc_dropdown_options", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/admin/abc_dropdown_options/:id
  # ---------------------------------------------------------------------------
  describe "PUT /api/v1/admin/abc_dropdown_options/:id" do
    let(:option) { create(:abc_dropdown_option, :antecedent, label: "Original Label") }

    let(:valid_params) do
      {
        abc_dropdown_option: {
          label:     "Updated Label",
          is_active: false
        }
      }
    end

    let(:invalid_params) do
      {
        abc_dropdown_option: {
          label:         "",
          display_order: -5
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the ABC dropdown option and returns 200" do
        put "/api/v1/admin/abc_dropdown_options/#{option.id}", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["label"]).to eq("Updated Label")
        expect(json["is_active"]).to eq(false)

        option.reload
        expect(option.label).to eq("Updated Label")
      end

      it "creates an audit log entry with changes" do
        option_id = option.id

        expect {
          put "/api/v1/admin/abc_dropdown_options/#{option_id}", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("AbcDropdownOption")
      end

      it "returns 422 with validation errors for invalid params" do
        put "/api/v1/admin/abc_dropdown_options/#{option.id}", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/abc_dropdown_options/#{option.id}", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/abc_dropdown_options/#{option.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/admin/abc_dropdown_options/:id
  # ---------------------------------------------------------------------------
  describe "DELETE /api/v1/admin/abc_dropdown_options/:id" do
    context "when authenticated as institutional admin" do
      let(:option) { create(:abc_dropdown_option, :antecedent) }

      it "deletes the ABC dropdown option and returns 204" do
        option_id = option.id

        expect {
          delete "/api/v1/admin/abc_dropdown_options/#{option_id}", headers: admin_headers
        }.to change(AbcDropdownOption, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it "creates an audit log entry" do
        option_id = option.id

        expect {
          delete "/api/v1/admin/abc_dropdown_options/#{option_id}", headers: admin_headers
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("destroy")
        expect(audit_log.resource_type).to eq("AbcDropdownOption")
      end
    end

    context "when authenticated as non-admin" do
      let(:option) { create(:abc_dropdown_option, :behavior) }

      it "returns 403 Forbidden" do
        delete "/api/v1/admin/abc_dropdown_options/#{option.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      let(:option) { create(:abc_dropdown_option, :consequence) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/admin/abc_dropdown_options/#{option.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/admin/abc_dropdown_options/reorder
  # ---------------------------------------------------------------------------
  describe "PUT /api/v1/admin/abc_dropdown_options/reorder" do
    let!(:opt1) { create(:abc_dropdown_option, :antecedent, label: "A1", display_order: 1) }
    let!(:opt2) { create(:abc_dropdown_option, :antecedent, label: "A2", display_order: 2) }
    let!(:opt3) { create(:abc_dropdown_option, :antecedent, label: "A3", display_order: 3) }

    let(:valid_params) do
      {
        category: "antecedent",
        ids:      [ opt3.id, opt1.id, opt2.id ]
      }
    end

    let(:invalid_params) do
      {
        category: "antecedent",
        ids:      [ 99999, opt1.id ]
      }
    end

    context "when authenticated as institutional admin" do
      it "reorders ABC dropdown options within a category and returns 200" do
        put "/api/v1/admin/abc_dropdown_options/reorder", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)

        opt1.reload
        opt2.reload
        opt3.reload

        expect(opt3.display_order).to eq(0)
        expect(opt1.display_order).to eq(1)
        expect(opt2.display_order).to eq(2)
      end

      it "creates an audit log entry with metadata" do
        expect {
          put "/api/v1/admin/abc_dropdown_options/reorder", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(4)   # 3 update logs + 1 reorder log

        reorder_log = AuditLog.where(action: "reorder", resource_type: "AbcDropdownOption").last
        expect(reorder_log).to be_present
        expect(reorder_log.metadata["category"]).to eq("antecedent")
        expect(reorder_log.metadata["ids"]).to eq([ opt3.id, opt1.id, opt2.id ])
      end

      it "returns 422 when category is missing" do
        put "/api/v1/admin/abc_dropdown_options/reorder",
            params: { ids: [ opt1.id, opt2.id ] },
            headers: admin_headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Category is required")
      end

      it "returns 422 with error message for invalid IDs" do
        put "/api/v1/admin/abc_dropdown_options/reorder", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/abc_dropdown_options/reorder", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/abc_dropdown_options/reorder", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
