# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Institutional Admin Settings Endpoints", type: :request do
  let(:admin_user) { create(:user, :institutional_admin) }
  let(:admin_headers) { authenticated_headers(admin_user) }

  describe "Goal Domains Underscored and Hyphen Alias" do
    let!(:domain1) { GoalDomain.create!(name: "Communication", display_order: 1) }
    let!(:domain2) { GoalDomain.create!(name: "Social Skills", display_order: 2) }

    it "supports GET /api/v1/admin/goal_domains (underscored endpoint)" do
      get "/api/v1/admin/goal_domains", headers: admin_headers

      expect(response).to have_http_status(:ok)
      names = JSON.parse(response.body).map { |d| d["name"] }
      expect(names).to include("Communication", "Social Skills")
    end

    it "supports PUT /api/v1/admin/goal_domains/reorder (underscored endpoint)" do
      put "/api/v1/admin/goal_domains/reorder",
          params: { ids: [ domain2.id, domain1.id ] },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(domain2.reload.display_order).to eq(0)
      expect(domain1.reload.display_order).to eq(1)
    end

    it "supports GET /api/v1/admin/goal-domains (hyphenated alias)" do
      get "/api/v1/admin/goal-domains", headers: admin_headers

      expect(response).to have_http_status(:ok)
      names = JSON.parse(response.body).map { |d| d["name"] }
      expect(names).to include("Communication", "Social Skills")
    end

    it "supports PUT /api/v1/admin/goal-domains/reorder (hyphenated alias)" do
      put "/api/v1/admin/goal-domains/reorder",
          params: { ids: [ domain2.id, domain1.id ] },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(domain2.reload.display_order).to eq(0)
      expect(domain1.reload.display_order).to eq(1)
    end
  end

  describe "Trial Config Routing to Prompt Levels" do
    let!(:level) { PromptLevel.create!(label: "Full Physical", color: "#E5484D", display_order: 1) }

    it "routes GET /api/v1/admin/trial-logging-config to prompt_levels#index" do
      get "/api/v1/admin/trial-logging-config", headers: admin_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.any? { |l| l["label"] == "Full Physical" }).to be true
    end

    it "routes POST /api/v1/admin/trial-logging-config to prompt_levels#save_trial_config" do
      post "/api/v1/admin/trial-logging-config",
           params: {
             streamCount: 10,
             consecutive: 3,
             prompt_levels: [
               { label: "Verbal Prompt", color: "#30A46C", order: 2 }
             ]
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(PromptLevel.exists?(label: "Verbal Prompt")).to be true
    end

    it "routes POST /api/v1/admin/prompt_levels with trial config to prompt_levels#save_trial_config" do
      post "/api/v1/admin/prompt_levels",
           params: {
             streamCount: 10,
             consecutive: 3,
             prompt_levels: [
               { label: "Gestural Prompt", color: "#F76B15", order: 3 }
             ]
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(PromptLevel.exists?(label: "Gestural Prompt")).to be true
    end

    it "routes PUT /api/v1/admin/prompt_levels to prompt_levels#save_trial_config" do
      put "/api/v1/admin/prompt_levels",
          params: {
            prompt_levels: [
              { label: "Model Prompt", color: "#0090FF", order: 4 }
            ]
          },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(PromptLevel.exists?(label: "Model Prompt")).to be true
    end

    it "routes POST /api/v1/admin/trial-config alias to prompt_levels#save_trial_config" do
      post "/api/v1/admin/trial-config",
           params: {
             prompt_levels: [
               { label: "Independent", color: "#46A758", order: 5 }
             ]
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(PromptLevel.exists?(label: "Independent")).to be true
    end
  end

  describe "Session Schedule Config with camelCase parameters" do
    before do
      SessionScheduleConfig.delete_all
    end

    it "transforms incoming camelCase parameters (morningStart, capacity, etc.)" do
      put "/api/v1/admin/session_schedule_config",
          params: {
            morningStart: "08:30 AM",
            morningEnd: "11:30 AM",
            afternoonStart: "01:30 PM",
            afternoonEnd: "04:30 PM",
            preTherapyDuration: 25,
            capacity: 5,
            draftExpiry: 14
          },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["staff_to_student_capacity"]).to eq(5)
      expect(json["capacity"]).to eq(5)
      expect(json["pre_therapy_duration_minutes"]).to eq(25)
      expect(json["preTherapyDuration"]).to eq(25)
      expect(json["draft_expiry_days"]).to eq(14)
      expect(json["draftExpiry"]).to eq(14)
      expect(json["morningStart"]).to eq("08:30 AM")

      config = SessionScheduleConfig.instance
      expect(config.staff_to_student_capacity).to eq(5)
      expect(config.draft_expiry_days).to eq(14)
      expect(config.morning_start_time.strftime("%H:%M")).to eq("08:30")
    end

    it "also accepts standard snake_case parameters" do
      put "/api/v1/admin/session_schedule_config",
          params: {
            session_schedule_config: {
              morning_start_time: "09:00",
              morning_end_time: "12:30",
              afternoon_start_time: "13:30",
              afternoon_end_time: "17:30",
              pre_therapy_duration_minutes: 30,
              station_1_duration_minutes: 40,
              station_2_duration_minutes: 40,
              staff_to_student_capacity: 6,
              draft_expiry_days: 10
            }
          },
          headers: admin_headers,
          as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["staff_to_student_capacity"]).to eq(6)
      expect(json["capacity"]).to eq(6)
      expect(json["staffToStudentCapacity"]).to eq(6)
      expect(json["pre_therapy_duration_minutes"]).to eq(30)
      expect(json["preTherapyDuration"]).to eq(30)
      expect(json["morningStart"]).to eq("09:00 AM")
      expect(json["morningStartTime"]).to eq("09:00 AM")

      config = SessionScheduleConfig.instance
      expect(config.staff_to_student_capacity).to eq(6)
      expect(config.morning_start_time.strftime("%H:%M")).to eq("09:00")
    end

    it "also works via POST /api/v1/admin/schedule-capacity-config compatibility route" do
      post "/api/v1/admin/schedule-capacity-config",
           params: {
             capacity: 3,
             draftExpiry: 5
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      config = SessionScheduleConfig.instance
      expect(config.staff_to_student_capacity).to eq(3)
      expect(config.draft_expiry_days).to eq(5)
    end
  end

  describe "ABC Lists Controller Location Persistence and is_other Flag (FR-149)" do
    let(:non_admin_user) { create(:user, :therapist) }
    let(:non_admin_headers) { authenticated_headers(non_admin_user) }

    before do
      AbcDropdownOption.destroy_all
    end

    it "persists locations in the database and loads them in GET /api/v1/admin/abc-lists" do
      get "/api/v1/admin/abc-lists", headers: admin_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["locations"]).to be_an(Array)
      loc_names = json["locations"].map { |l| l["name"] }
      expect(loc_names).to include("Classroom", "Playground", "Sensory Room", "Cafeteria")
    end

    it "saves new locations and updates is_other via POST /api/v1/admin/abc-lists/locations" do
      post "/api/v1/admin/abc-lists/locations",
           params: {
             items: [
               { name: "Gymnasium", status: "Active", is_other: false },
               { name: "Custom Location Other", status: "Active", is_other: true }
             ]
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)

      gym = AbcDropdownOption.find_by(category: :location, label: "Gymnasium")
      expect(gym).to be_present
      expect(gym.is_other).to be false

      other_loc = AbcDropdownOption.find_by(category: :location, label: "Custom Location Other")
      expect(other_loc).to be_present
      expect(other_loc.is_other).to be true
    end

    it "atomically updates is_other when another item is designated as Other" do
      first_loc = AbcDropdownOption.create!(
        category: :location,
        label: "Location Alpha",
        display_order: 1,
        is_active: true,
        is_other: true
      )

      post "/api/v1/admin/abc-lists/locations",
           params: {
             items: [
               { id: first_loc.id, name: "Location Alpha", is_other: false },
               { name: "Location Beta Other", is_other: true }
             ]
           },
           headers: admin_headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(first_loc.reload.is_other).to be false
      beta = AbcDropdownOption.find_by(category: :location, label: "Location Beta Other")
      expect(beta).to be_present
      expect(beta.is_other).to be true
      expect(AbcDropdownOption.where(category: :location, is_other: true).count).to eq(1)
    end

    it "serializes is_other and isOther boolean flags in GET /api/v1/admin/abc-lists" do
      AbcDropdownOption.create!(
        category: :behavior,
        label: "Special Behavior",
        display_order: 1,
        is_active: true,
        is_other: true
      )

      get "/api/v1/admin/abc-lists", headers: admin_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      item = json["behaviors"].find { |b| b["name"] == "Special Behavior" }
      expect(item).to be_present
      expect(item["is_other"]).to be true
      expect(item["isOther"]).to be true
    end

    it "forbids non-admin users from accessing abc-lists" do
      get "/api/v1/admin/abc-lists", headers: non_admin_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
