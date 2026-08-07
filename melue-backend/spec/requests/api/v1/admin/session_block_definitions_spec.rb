# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Admin::SessionBlockDefinitions", type: :request do
  let(:admin_user)       { create(:user, :institutional_admin) }
  let(:non_admin_user)   { create(:user, :therapist) }
  let(:admin_headers)    { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/session_block_definitions
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/session_block_definitions" do
    let!(:blocks) do
      [
        create(:session_block_definition, name: "Morning",   start_time: "08:00", end_time: "09:30"),
        create(:session_block_definition, name: "Afternoon", start_time: "13:00", end_time: "14:30"),
        create(:session_block_definition, name: "Evening",   start_time: "17:00", end_time: "18:30")
      ]
    end

    context "when authenticated as institutional admin" do
      it "returns all session block definitions ordered by start_time" do
        get "/api/v1/admin/session_block_definitions", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
        expect(json.first["name"]).to eq("Morning")
        expect(json.second["name"]).to eq("Afternoon")
        expect(json.third["name"]).to eq("Evening")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/session_block_definitions", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/session_block_definitions"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/admin/session_block_definitions/:id
  # ---------------------------------------------------------------------------
  describe "GET /api/v1/admin/session_block_definitions/:id" do
    let(:block) { create(:session_block_definition, name: "Morning Block") }

    context "when authenticated as institutional admin" do
      it "returns the specified session block definition" do
        get "/api/v1/admin/session_block_definitions/#{block.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(block.id)
        expect(json["name"]).to eq("Morning Block")
      end

      it "returns 404 when session block definition not found" do
        get "/api/v1/admin/session_block_definitions/99999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/session_block_definitions/#{block.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/session_block_definitions/#{block.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/admin/session_block_definitions
  # ---------------------------------------------------------------------------
  describe "POST /api/v1/admin/session_block_definitions" do
    let(:valid_params) do
      {
        session_block_definition: {
          name:       "New Block",
          start_time: "10:00",
          end_time:   "11:30",
          round:      "morning",
          is_active:  true
        }
      }
    end

    let(:invalid_params) do
      {
        session_block_definition: {
          name:       "",
          start_time: "10:00",
          end_time:   "09:00",   # end before start — fails validation
          round:      "morning"
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "creates a new session block definition and returns 201" do
        expect {
          post "/api/v1/admin/session_block_definitions", params: valid_params, headers: admin_headers, as: :json
        }.to change(SessionBlockDefinition, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("New Block")
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/admin/session_block_definitions", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("create")
        expect(audit_log.resource_type).to eq("SessionBlockDefinition")
      end

      it "returns 422 with validation errors for invalid params" do
        post "/api/v1/admin/session_block_definitions", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end

      it "returns 422 when end_time is before start_time" do
        params = {
          session_block_definition: {
            name:       "Bad Block",
            start_time: "14:00",
            end_time:   "13:00",
            round:      "afternoon"
          }
        }

        post "/api/v1/admin/session_block_definitions", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["end_time"]).to include("must be after start time")
      end

      it "returns 422 when end_time equals start_time" do
        params = {
          session_block_definition: {
            name:       "Equal Time Block",
            start_time: "10:00",
            end_time:   "10:00",
            round:      "morning"
          }
        }

        post "/api/v1/admin/session_block_definitions", params: params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]["end_time"]).to include("must be after start time")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/session_block_definitions", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/session_block_definitions", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/admin/session_block_definitions/:id
  # ---------------------------------------------------------------------------
  describe "PUT /api/v1/admin/session_block_definitions/:id" do
    let(:block) { create(:session_block_definition, name: "Original Block") }

    let(:valid_params) do
      {
        session_block_definition: {
          name:      "Updated Block",
          is_active: false
        }
      }
    end

    let(:invalid_params) do
      {
        session_block_definition: {
          name:       "",
          start_time: "15:00",
          end_time:   "14:00"   # end before start
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the session block definition and returns 200" do
        put "/api/v1/admin/session_block_definitions/#{block.id}", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("Updated Block")
        expect(json["is_active"]).to eq(false)

        block.reload
        expect(block.name).to eq("Updated Block")
      end

      it "creates an audit log entry with changes" do
        block_id = block.id

        expect {
          put "/api/v1/admin/session_block_definitions/#{block_id}", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("SessionBlockDefinition")
      end

      it "returns 422 with validation errors for invalid params" do
        put "/api/v1/admin/session_block_definitions/#{block.id}", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/session_block_definitions/#{block.id}", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/session_block_definitions/#{block.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/admin/session_block_definitions/:id
  # ---------------------------------------------------------------------------
  describe "DELETE /api/v1/admin/session_block_definitions/:id" do
    context "when authenticated as institutional admin" do
      context "with no dependencies" do
        let(:block) { create(:session_block_definition) }

        it "deletes the session block definition and returns 204" do
          block_id = block.id

          expect {
            delete "/api/v1/admin/session_block_definitions/#{block_id}", headers: admin_headers
          }.to change(SessionBlockDefinition, :count).by(-1)

          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_empty
        end

        it "creates an audit log entry" do
          block_id = block.id

          expect {
            delete "/api/v1/admin/session_block_definitions/#{block_id}", headers: admin_headers
          }.to change(AuditLog, :count).by(1)

          audit_log = AuditLog.last
          expect(audit_log.action).to eq("destroy")
          expect(audit_log.resource_type).to eq("SessionBlockDefinition")
        end
      end

      context "with existing therapy sessions dependency" do
        let(:block)    { create(:session_block_definition) }
        let!(:session) { create(:therapy_session, session_block_definition: block) }

        it "returns 422 with error message" do
          expect {
            delete "/api/v1/admin/session_block_definitions/#{block.id}", headers: admin_headers
          }.not_to change(SessionBlockDefinition, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json).to have_key("error")
        end
      end
    end

    context "when authenticated as non-admin" do
      let(:block) { create(:session_block_definition) }

      it "returns 403 Forbidden" do
        delete "/api/v1/admin/session_block_definitions/#{block.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      let(:block) { create(:session_block_definition) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/admin/session_block_definitions/#{block.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
