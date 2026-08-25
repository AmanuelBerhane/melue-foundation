require 'rails_helper'

RSpec.describe "Admin::Roles", type: :request do
  let(:admin_user) do
    user = create(:user, email: "admin_test@melue.foundation", password: "Password123!")
    role = Role.create!(name: "System Admin Test", is_system_critical: true)
    Permission.create!(resource: "roles", action: "index")
    Permission.create!(resource: "roles", action: "create")
    role.permissions = Permission.where(resource: "roles")
    UserRole.create!(user: user, role: role)
    user
  end

  let(:basic_user) do
    create(:user, email: "basic_test@melue.foundation", password: "Password123!")
  end

  describe "GET /api/v1/admin/roles" do
    it "allows access if user has 'roles index' permission" do
      get "/api/v1/admin/roles", headers: authenticated_headers(admin_user)

      expect(response).to have_http_status(:success)
    end

    it "blocks access if user does not have permission" do
      get "/api/v1/admin/roles", headers: authenticated_headers(basic_user)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("You do not have permission to index roles.")
    end
  end

  describe "POST /api/v1/admin/roles" do
    it "creates a role when authorized" do
      post "/api/v1/admin/roles",
           params: { name: "New Coordinator", description: "Test Role" },
           headers: authenticated_headers(admin_user),
           as: :json

      expect(response).to have_http_status(:created)
      expect(Role.exists?(name: "New Coordinator")).to be true
    end
  end
end
