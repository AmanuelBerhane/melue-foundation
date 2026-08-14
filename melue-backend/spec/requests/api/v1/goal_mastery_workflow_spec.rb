# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goal Mastery Workflow API", type: :request do
  let(:teacher_a_user) { create(:user) }
  let(:teacher_b_user) { create(:user) }
  let(:teacher_c_user) { create(:user) }
  let(:pd_user)        { create(:user) }

  let!(:teacher_a) { create(:staff_member, user: teacher_a_user) }
  let!(:teacher_b) { create(:staff_member, user: teacher_b_user) }
  let!(:teacher_c) { create(:staff_member, user: teacher_c_user) }
  let!(:pd)        { create(:staff_member, user: pd_user) }

  let(:student) { create(:student) }
  let(:iup) { create(:iup, student: student) }
  let(:station) { create(:therapy_station) }
  let(:student_goal) { create(:student_goal, student: student, iup: iup, therapy_station: station, status: "in_progress") }

  describe "End-to-End Workflow" do
    it "processes the goal mastery checks correctly" do
      # 1. Teacher A creates mastery check
      post "/api/v1/student_goals/#{student_goal.id}/mastery_checks",
           headers: authenticated_headers(teacher_a_user),
           as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      mastery_check_id = json["mastery_check"]["id"]
      expect(json["mastery_check"]["status"]).to eq("pending_verifications")

      # 2. Teacher B verifies
      post "/api/v1/mastery_checks/#{mastery_check_id}/verifications",
           params: { outcome: "success", notes: "Good job" },
           headers: authenticated_headers(teacher_b_user),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["mastery_check"]["status"]).to eq("pending_verifications")

      # 3. Teacher C verifies -> auto upgrades status
      post "/api/v1/mastery_checks/#{mastery_check_id}/verifications",
           params: { outcome: "success", notes: "Great job" },
           headers: authenticated_headers(teacher_c_user),
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["mastery_check"]["status"]).to eq("pending_approval")
      expect(student_goal.reload.status).to eq("pending_approval")

      # 4. Program Director approves
      patch "/api/v1/mastery_checks/#{mastery_check_id}/approve",
            headers: authenticated_headers(pd_user),
            as: :json

      expect(response).to have_http_status(:ok)

      mastery_check = GoalMasteryCheck.find(mastery_check_id)
      expect(mastery_check.status).to eq("approved")
      expect(mastery_check.approving_director_id).to eq(pd.id)
      expect(student_goal.reload.status).to eq("mastered")
    end
  end
end
