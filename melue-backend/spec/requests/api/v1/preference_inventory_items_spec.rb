# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PreferenceInventoryItems", type: :request do
  let(:user)     { create(:user) }
  let!(:teacher) { create(:staff_member, user: user) }
  let(:headers)  { authenticated_headers(user) }

  describe "GET /api/v1/preference_inventory_items" do
    before do
      create(:preference_inventory_item, name: "Balloon",    category: "Visual")
      create(:preference_inventory_item, name: "Flashlight", category: "Visual")
      create(:preference_inventory_item, name: "Music",      category: "Auditory")
      create(:preference_inventory_item, :inactive, name: "Retired item", category: "Visual")
    end

    it "returns the active inventory grouped by category (FR-047a)" do
      get "/api/v1/preference_inventory_items", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      categories = response.parsed_body["categories"]

      expect(categories.map { |c| c["category"] }).to eq(%w[Auditory Visual])

      visual = categories.find { |c| c["category"] == "Visual" }
      expect(visual["items"].map { |i| i["name"] }).to eq(%w[Balloon Flashlight])
    end

    it "omits deactivated items so past observations keep their references" do
      get "/api/v1/preference_inventory_items", headers: headers, as: :json

      names = response.parsed_body["categories"].flat_map { |c| c["items"] }.map { |i| i["name"] }
      expect(names).not_to include("Retired item")
    end

    it "returns 401 without a token" do
      get "/api/v1/preference_inventory_items", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a user with no staff profile" do
      other = create(:user)

      get "/api/v1/preference_inventory_items", headers: authenticated_headers(other), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
