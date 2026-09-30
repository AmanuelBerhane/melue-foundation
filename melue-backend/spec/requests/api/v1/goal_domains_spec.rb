# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goal Domains API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  before do
    create(:staff_member, user: user, role: "teacher")
  end

  describe "GET /api/v1/goal_domains (FR-073)" do
    let!(:domain1) { create(:goal_domain, name: "Communication", display_order: 1) }
    let!(:domain2) { create(:goal_domain, name: "Motor Skills", display_order: 2) }
    let!(:inactive_domain) { create(:goal_domain, name: "Deprecated Domain", is_active: false, display_order: 3) }

    before do
      create(:goal, goal_domain: domain1, is_active: true)
      create(:goal, goal_domain: domain1, is_active: true)
      create(:goal, goal_domain: domain1, is_active: false) # Inactive goal
      create(:goal, goal_domain: domain2, is_active: true)
    end

    it "returns 200 and lists active domains ordered by display_order" do
      get "/api/v1/goal_domains", headers: headers

      expect(response).to have_http_status(:ok)
      data = json
      expect(data.size).to eq(2)
      expect(data[0]["id"]).to eq(domain1.id)
      expect(data[0]["name"]).to eq("Communication")
      expect(data[0]["goals_count"]).to eq(2)

      expect(data[1]["id"]).to eq(domain2.id)
      expect(data[1]["name"]).to eq("Motor Skills")
      expect(data[1]["goals_count"]).to eq(1)
    end

    it "requires authentication" do
      get "/api/v1/goal_domains"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/goal_domains/:id" do
    let(:domain) { create(:goal_domain, name: "Social") }

    it "returns domain details" do
      get "/api/v1/goal_domains/#{domain.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(domain.id)
      expect(json["name"]).to eq("Social")
    end

    it "returns 404 for nonexistent domain" do
      get "/api/v1/goal_domains/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
