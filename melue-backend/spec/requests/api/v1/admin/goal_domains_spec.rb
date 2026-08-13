require "rails_helper"

RSpec.describe "Api::V1::Admin::GoalDomains", type: :request do
  let(:admin_user) { create(:user, :institutional_admin) }
  let(:non_admin_user) { create(:user, :therapist) }
  let(:admin_headers) { authenticated_headers(admin_user) }
  let(:non_admin_headers) { authenticated_headers(non_admin_user) }

  describe "GET /api/v1/admin/goal_domains" do
    let!(:goal_domains) do
      [
        create(:goal_domain, name: "Communication", display_order: 1),
        create(:goal_domain, name: "Social Skills", display_order: 2),
        create(:goal_domain, name: "Self-Care", display_order: 3)
      ]
    end

    context "when authenticated as institutional admin" do
      it "returns all goal domains ordered by display_order" do
        get "/api/v1/admin/goal_domains", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
        expect(json.first["name"]).to eq("Communication")
        expect(json.second["name"]).to eq("Social Skills")
        expect(json.third["name"]).to eq("Self-Care")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/goal_domains", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/goal_domains"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/admin/goal_domains/:id" do
    let(:goal_domain) { create(:goal_domain, name: "Communication") }

    context "when authenticated as institutional admin" do
      it "returns the specified goal domain" do
        get "/api/v1/admin/goal_domains/#{goal_domain.id}", headers: admin_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(goal_domain.id)
        expect(json["name"]).to eq("Communication")
      end

      it "returns 404 when goal domain not found" do
        get "/api/v1/admin/goal_domains/99999", headers: admin_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        get "/api/v1/admin/goal_domains/#{goal_domain.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        get "/api/v1/admin/goal_domains/#{goal_domain.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/admin/goal_domains" do
    let(:valid_params) do
      {
        goal_domain: {
          name: "New Domain",
          description: "A new goal domain",
          display_order: 5,
          is_active: true
        }
      }
    end

    let(:invalid_params) do
      {
        goal_domain: {
          name: "",
          display_order: -1
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "creates a new goal domain and returns 201" do
        expect {
          post "/api/v1/admin/goal_domains", params: valid_params, headers: admin_headers, as: :json
        }.to change(GoalDomain, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("New Domain")
        expect(json["display_order"]).to eq(5)
      end

      it "creates an audit log entry" do
        expect {
          post "/api/v1/admin/goal_domains", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("create")
        expect(audit_log.resource_type).to eq("GoalDomain")
      end

      it "returns 422 with validation errors for invalid params" do
        post "/api/v1/admin/goal_domains", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]).to have_key("name")
        expect(json["errors"]).to have_key("display_order")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        post "/api/v1/admin/goal_domains", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/goal_domains", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/admin/goal_domains/:id" do
    let(:goal_domain) { create(:goal_domain, name: "Original Name") }

    let(:valid_params) do
      {
        goal_domain: {
          name: "Updated Name",
          is_active: false
        }
      }
    end

    let(:invalid_params) do
      {
        goal_domain: {
          name: "",
          display_order: -5
        }
      }
    end

    context "when authenticated as institutional admin" do
      it "updates the goal domain and returns 200" do
        put "/api/v1/admin/goal_domains/#{goal_domain.id}", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(a_string_including("application/json"))
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("Updated Name")
        expect(json["is_active"]).to eq(false)

        goal_domain.reload
        expect(goal_domain.name).to eq("Updated Name")
      end

      it "creates an audit log entry with changes" do
        goal_domain_id = goal_domain.id

        expect {
          put "/api/v1/admin/goal_domains/#{goal_domain_id}", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.action).to eq("update")
        expect(audit_log.resource_type).to eq("GoalDomain")
      end

      it "returns 422 with validation errors for invalid params" do
        put "/api/v1/admin/goal_domains/#{goal_domain.id}", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/goal_domains/#{goal_domain.id}", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/goal_domains/#{goal_domain.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/admin/goal_domains/:id" do
    context "when authenticated as institutional admin" do
      context "with no dependencies" do
        let(:goal_domain) { create(:goal_domain) }

        it "deletes the goal domain and returns 204" do
          goal_domain_id = goal_domain.id

          expect {
            delete "/api/v1/admin/goal_domains/#{goal_domain_id}", headers: admin_headers
          }.to change(GoalDomain, :count).by(-1)

          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_empty
        end

        it "creates an audit log entry" do
          goal_domain_id = goal_domain.id

          expect {
            delete "/api/v1/admin/goal_domains/#{goal_domain_id}", headers: admin_headers
          }.to change(AuditLog, :count).by(1)

          audit_log = AuditLog.last
          expect(audit_log.action).to eq("destroy")
          expect(audit_log.resource_type).to eq("GoalDomain")
        end
      end

      context "with existing goals dependency" do
        let(:goal_domain) { create(:goal_domain) }
        let!(:goal) { create(:goal, goal_domain: goal_domain) }

        it "returns 422 with error message" do
          expect {
            delete "/api/v1/admin/goal_domains/#{goal_domain.id}", headers: admin_headers
          }.not_to change(GoalDomain, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json).to have_key("error")
          expect(json["error"]).to include("existing goals")
        end
      end
    end

    context "when authenticated as non-admin" do
      let(:goal_domain) { create(:goal_domain) }

      it "returns 403 Forbidden" do
        delete "/api/v1/admin/goal_domains/#{goal_domain.id}", headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      let(:goal_domain) { create(:goal_domain) }

      it "returns 401 Unauthorized" do
        delete "/api/v1/admin/goal_domains/#{goal_domain.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/admin/goal_domains/reorder" do
    let!(:domain1) { create(:goal_domain, display_order: 1) }
    let!(:domain2) { create(:goal_domain, display_order: 2) }
    let!(:domain3) { create(:goal_domain, display_order: 3) }

    let(:valid_params) do
      {
        ids: [ domain3.id, domain1.id, domain2.id ]
      }
    end

    let(:invalid_params) do
      {
        ids: [ 99999, domain1.id ]
      }
    end

    context "when authenticated as institutional admin" do
      it "reorders goal domains and returns 200" do
        put "/api/v1/admin/goal_domains/reorder", params: valid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:ok)

        domain1.reload
        domain2.reload
        domain3.reload

        expect(domain3.display_order).to eq(0)
        expect(domain1.display_order).to eq(1)
        expect(domain2.display_order).to eq(2)
      end

      it "creates an audit log entry with metadata" do
        expect {
          put "/api/v1/admin/goal_domains/reorder", params: valid_params, headers: admin_headers, as: :json
        }.to change(AuditLog, :count).by(4)

        reorder_audit_log = AuditLog.where(action: "reorder", resource_type: "GoalDomain").last
        expect(reorder_audit_log).to be_present
        expect(reorder_audit_log.metadata["ids"]).to eq([ domain3.id, domain1.id, domain2.id ])
      end

      it "returns 422 with error message for invalid IDs" do
        put "/api/v1/admin/goal_domains/reorder", params: invalid_params, headers: admin_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "when authenticated as non-admin" do
      it "returns 403 Forbidden" do
        put "/api/v1/admin/goal_domains/reorder", params: valid_params, headers: non_admin_headers, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when unauthenticated" do
      it "returns 401 Unauthorized" do
        put "/api/v1/admin/goal_domains/reorder", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
