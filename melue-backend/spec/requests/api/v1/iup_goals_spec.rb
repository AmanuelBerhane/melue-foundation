# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::IupGoals", type: :request do
  let(:pd_user) { create(:user) }
  let!(:pd_staff) { create(:staff_member, user: pd_user) }
  let(:headers) { authenticated_headers(pd_user) }

  let!(:pd_role) { Role.find_or_create_by!(name: "Program Director") }
  let!(:pd_role_assignment) { RoleAssignment.create!(user: pd_user, role: pd_role) }

  let(:student) { create(:student) }
  let(:iup) { create(:iup, :draft, student: student) }
  let(:goal) { create(:goal, applicable_therapy_groups: [student.therapy_group]) }
  let(:station) { create(:therapy_station) }

  # --- CREATE ---
  describe "POST /api/v1/iups/:iup_id/goals" do
    it "assigns a goal to the IUP" do
      expect {
        post "/api/v1/iups/#{iup.id}/goals",
             params: { goal_id: goal.id, therapy_station_id: station.id },
             headers: headers, as: :json
      }.to change(StudentGoal, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json.dig("student_goal", "goal", "id")).to eq(goal.id)
      expect(json.dig("student_goal", "therapy_station", "id")).to eq(station.id)
    end

    it "rejects adding goals to a finalized IUP" do
      iup.update!(status: "active")

      post "/api/v1/iups/#{iup.id}/goals",
           params: { goal_id: goal.id, therapy_station_id: station.id },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("active")
    end

    it "enforces max 2 goals per station" do
      create(:student_goal, iup: iup, student: student, therapy_station: station, goal: create(:goal, applicable_therapy_groups: [student.therapy_group]))
      create(:student_goal, iup: iup, student: student, therapy_station: station, goal: create(:goal, applicable_therapy_groups: [student.therapy_group]))

      post "/api/v1/iups/#{iup.id}/goals",
           params: { goal_id: goal.id, therapy_station_id: station.id },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # --- UPDATE (replace goal) ---
  describe "PATCH /api/v1/iups/:iup_id/goals/:id" do
    let(:student_goal) { create(:student_goal, iup: iup, student: student, therapy_station: station, goal: goal) }
    let(:new_goal) { create(:goal, applicable_therapy_groups: [student.therapy_group]) }

    it "replaces the goal assignment" do
      patch "/api/v1/iups/#{iup.id}/goals/#{student_goal.id}",
            params: { new_goal_id: new_goal.id },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("student_goal", "goal", "id")).to eq(new_goal.id)
    end

    it "rejects replacement on a finalized IUP" do
      iup.update!(status: "active")

      patch "/api/v1/iups/#{iup.id}/goals/#{student_goal.id}",
            params: { new_goal_id: new_goal.id },
            headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # --- DESTROY ---
  describe "DELETE /api/v1/iups/:iup_id/goals/:id" do
    let!(:student_goal) { create(:student_goal, iup: iup, student: student, therapy_station: station, goal: goal) }

    it "removes the goal from a draft IUP" do
      delete "/api/v1/iups/#{iup.id}/goals/#{student_goal.id}",
             headers: headers, as: :json

      expect(response).to have_http_status(:no_content)
    end

    it "rejects removal from a finalized IUP" do
      iup.update!(status: "active")

      delete "/api/v1/iups/#{iup.id}/goals/#{student_goal.id}",
             headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
