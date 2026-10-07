# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sysadmin Permissions Management", type: :request do
  let(:admin_role) { Role.find_or_create_by!(name: Role::Names::SYSTEM_ADMIN) { |r| r.is_system_critical = true } }
  let(:teacher_role) { Role.find_or_create_by!(name: Role::Names::TEACHER) { |r| r.is_system_critical = false } }
  let(:admin_user) do
    User.create!(
      email: "sysadmin_test_#{SecureRandom.hex(4)}@melue.foundation",
      password_hash: BCrypt::Password.create("Password123!"),
      status: :verified,
      role: :system_admin
    ).tap do |u|
      u.assign_role(admin_role)
    end
  end

  let(:auth_headers) do
    post "/api/v1/auth/login", params: { email: admin_user.email, password: "Password123!" }, as: :json
    { "Authorization" => response.headers["Authorization"], "Accept" => "application/json" }
  end

  describe "GET /api/v1/sysadmin/permissions" do
    it "returns the full permissions catalog grouped by module" do
      get "/api/v1/sysadmin/permissions", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key("modules")
      expect(json).to have_key("actions")
      expect(json["actions"]).to include("VIEW", "CREATE", "EDIT", "DELETE", "APPROVE")
      expect(json["modules"].size).to be >= 7

      first_module = json["modules"].first
      expect(first_module).to have_key("id")
      expect(first_module).to have_key("name")
      expect(first_module).to have_key("permissions")
    end
  end

  describe "POST /api/v1/sysadmin/roles/:id/permissions" do
    it "updates role permissions and records an audit log" do
      perm = Permission.find_or_create_by!(resource: "students", action: "view")

      post "/api/v1/sysadmin/roles/#{teacher_role.id}/permissions",
           params: { permission_ids: [ perm.id ] },
           headers: auth_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(teacher_role.reload.permissions).to include(perm)

      # Verify audit log
      get "/api/v1/sysadmin/roles/#{teacher_role.id}/permissions/audit", headers: auth_headers
      expect(response).to have_http_status(:ok)
      audit_json = JSON.parse(response.body)
      expect(audit_json.size).to be >= 1
    end
  end

  describe "POST /api/v1/sysadmin/roles/:id/permissions/reset-default" do
    it "resets role permissions to standard template defaults" do
      post "/api/v1/sysadmin/roles/#{admin_role.id}/permissions/reset-default",
           headers: auth_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(json["permissions"]).not_to be_empty
    end
  end

  describe "POST /api/v1/sysadmin/roles/:id/permissions/copy-from" do
    it "copies permissions from source role" do
      post "/api/v1/sysadmin/roles/#{teacher_role.id}/permissions/copy-from",
           params: { source_role_id: admin_role.id },
           headers: auth_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(teacher_role.reload.permissions.count).to eq(admin_role.permissions.count)
    end
  end
end
