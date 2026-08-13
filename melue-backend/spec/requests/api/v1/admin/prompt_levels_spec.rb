require "rails_helper"

RSpec.describe "Api::V1::Admin::PromptLevels", type: :request do
  let(:admin_user) { create(:user, :institutional_admin) }
  let(:non_admin_user) { create(:user, :therapist) }
  let(:admin_headers) { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  describe "GET /api/v1/admin/prompt_levels" do
    let!(:prompt_levels) do
      [
        create(:prompt_level, label: "FP", color: "#FF0000", display_order: 1),
        create(:prompt_level, label: "PP", color: "#FFA500", display_order: 2),
        create(:prompt_level, label: "G", color: "#FFFF00", display_order: 3)
      ]
    end

    context "when authenticated as institutional admin" do
      it "returns all prompt levels ordered by display_order" do
        get "/api/v1/admin/prompt_levels", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
        expect(json.first["label"]).to eq("FP")
        expect(json.second["label"]).to eq("PP")
        expect(json.third["label"]).to eq("G")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/prompt_levels", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/prompt_levels"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/prompt_levels/:id" do
    let(:prompt_level) { create(:prompt_level, label: "FP", color: "#FF0000") }

    context "when authenticated as institutional admin" do
      it "returns the specified prompt level" do
        get "/api/v1/admin/prompt_levels/#{prompt_level.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(prompt_level.id)
        expect(json["label"]).to eq("FP")
        expect(json["color"]).to eq("#FF0000")
      end

      it "returns 404 when prompt level not found" do
        get "/api/v1/admin/prompt_levels/99999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/prompt_levels/#{prompt_level.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/prompt_levels/#{prompt_level.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/admin/prompt_levels" do
    let(:valid_params) do
      {
        prompt_level: {
          label: "New Level",
          color: "#00FF00",
          display_order: 5,
          is_active: true
        }
      }
    end

    let(:invalid_params) do
      {
        prompt_level: {
          label: "",
          color: "invalid",
          display_order: -1
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "creates a new prompt level and returns 201" do
        expect {
          post "/api/v1/admin/prompt_levels", params: valid_params, headers: admin_headers, as: :json
        }.to change(PromptLevel, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["label"]).to eq("New Level")
        expect(json["color"]).to eq("#00FF00")
        expect(json["display_order"]).to eq(5)
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/admin/prompt_levels", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("create")
        expect(audit_log.resource_type).to eq("PromptLevel")
      end

      it "returns 422 with validation errors for invalid params" do
        post "/api/v1/admin/prompt_levels", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]).to have_key("label")
        expect(json["errors"]).to have_key("color")
        expect(json["errors"]).to have_key("display_order")
      end

      it "returns 422 with validation error for invalid hex color" do
        invalid_color_params = {
          prompt_level: {
            label: "Test",
            color: "not-a-hex",
            display_order: 1
          }
        }

        post "/api/v1/admin/prompt_levels", params: invalid_color_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["color"]).to include("must be a valid hex code")
      end

      it "accepts hex color without hash prefix" do
        params_without_hash = {
          prompt_level: {
            label: "Test Level",
            color: "FF0000",
            display_order: 1
          }
        }

        post "/api/v1/admin/prompt_levels", params: params_without_hash, headers: admin_headers, as: :json

        expect(response).to have_http_status(:created)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/prompt_levels", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/prompt_levels", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/admin/prompt_levels/:id" do
    let(:prompt_level) { create(:prompt_level, label: "Original", color: "#FF0000") }

    let(:valid_params) do
      {
        prompt_level: {
          label: "Updated",
          color: "#00FF00",
          is_active: false
        }
      }
    end

    let(:invalid_params) do
      {
        prompt_level: {
          label: "",
          color: "bad-color",
          display_order: -5
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the prompt level and returns 200" do
        put "/api/v1/admin/prompt_levels/#{prompt_level.id}", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["label"]).to eq("Updated")
        expect(json["color"]).to eq("#00FF00")
        expect(json["is_active"]).to eq(false)

        prompt_level.reload
        expect(prompt_level.label).to eq("Updated")
        expect(prompt_level.color).to eq("#00FF00")
      end

      it "creates an audit log entry with changes" do
        prompt_level_id = prompt_level.id

        expect {
          put "/api/v1/admin/prompt_levels/#{prompt_level_id}", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("PromptLevel")
      end

      it "returns 422 with validation errors for invalid params" do
        put "/api/v1/admin/prompt_levels/#{prompt_level.id}", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/prompt_levels/#{prompt_level.id}", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/prompt_levels/#{prompt_level.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/admin/prompt_levels/:id" do
    context "when authenticated as institutional admin" do
      context "with no dependencies" do
        let(:prompt_level) { create(:prompt_level) }

        it "deletes the prompt level and returns 204" do
          prompt_level_id = prompt_level.id

          expect {
            delete "/api/v1/admin/prompt_levels/#{prompt_level_id}", headers: admin_headers
          }.to change(PromptLevel, :count).by(-1)

          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_empty
        end

        it "creates an audit log entry" do
          prompt_level_id = prompt_level.id

          expect {
            delete "/api/v1/admin/prompt_levels/#{prompt_level_id}", headers: admin_headers
          }.to change(AuditLog, :count).by(1)

          audit_log = AuditLog.last
          expect(audit_log.action).to eq("destroy")
          expect(audit_log.resource_type).to eq("PromptLevel")
        end
      end

      context "with existing trials dependency" do
        let(:prompt_level) { create(:prompt_level) }
        let!(:trial) { create(:trial, prompt_level: prompt_level) }

        it "returns 422 with error message" do
          expect {
            delete "/api/v1/admin/prompt_levels/#{prompt_level.id}", headers: admin_headers
          }.not_to change(PromptLevel, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json).to have_key("error")
          expect(json["error"]).to include("existing trials")
        end
      end
    end

    context "when authenticated as non-admin" do
      let(:prompt_level) { create(:prompt_level) }

      it "returns 403 Forbidden" do
        delete "/api/v1/admin/prompt_levels/#{prompt_level.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      let(:prompt_level) { create(:prompt_level) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/admin/prompt_levels/#{prompt_level.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/admin/prompt_levels/reorder" do
    let!(:level1) { create(:prompt_level, display_order: 1) }
    let!(:level2) { create(:prompt_level, display_order: 2) }
    let!(:level3) { create(:prompt_level, display_order: 3) }

    let(:valid_params) do
      {
        ids: [ level3.id, level1.id, level2.id ]
      }
    end

    let(:invalid_params) do
      {
        ids: [ 99999, level1.id ]
      }
    end

    context "when authenticated as institutional admin" do
      it "reorders prompt levels and returns 200" do
        put "/api/v1/admin/prompt_levels/reorder", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)

        level1.reload
        level2.reload
        level3.reload

        expect(level3.display_order).to eq(0)
        expect(level1.display_order).to eq(1)
        expect(level2.display_order).to eq(2)
      end

      it "creates an audit log entry with metadata" do
        expect {
          put "/api/v1/admin/prompt_levels/reorder", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(4)

        reorder_audit_log = AuditLog.where(action: "reorder", resource_type: "PromptLevel").last
        expect(reorder_audit_log).to be_present
        expect(reorder_audit_log.metadata["ids"]).to eq([ level3.id, level1.id, level2.id ])
      end

      it "returns 422 with error message for invalid IDs" do
        put "/api/v1/admin/prompt_levels/reorder", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/prompt_levels/reorder", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/prompt_levels/reorder", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
