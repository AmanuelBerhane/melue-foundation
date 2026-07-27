require "rails_helper"

RSpec.describe "Authentication API", type: :request do
  describe "POST /api/v1/auth/create-account" do
    it "creates a new user account" do
      post "/api/v1/auth/create-account",
           params: { email: "test@example.com", password: "password123", "password-confirm": "password123" },
           as: :json

      expect(response).to have_http_status(:success)
      expect(User.find_by(email: "test@example.com")).to be_present
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "user@example.com") }

    it "logs in with valid credentials and returns a JWT" do
      post "/api/v1/auth/login",
           params: { email: "user@example.com", password: "password123" },
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.headers["Authorization"]).to be_present
    end

    it "rejects invalid credentials" do
      post "/api/v1/auth/login",
           params: { email: "user@example.com", password: "wrongpassword" },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
