# spec/requests/api/v1/goals/assignments_spec.rb
require 'rails_helper'

RSpec.describe 'Goal Assignments API', type: :request do
  let(:user) { create(:user, role: :institutional_admin) }
  let(:staff_member) { create(:staff_member, user: user, role: 'program_director') }
  let(:headers) { auth_headers(user) }

  # Make sure the staff_member is created before each test
  before do
    staff_member # This creates the staff_member
  end

  describe 'POST /api/v1/goal_assignments' do
    let(:student) { create(:student) }
    let(:goal) { create(:goal, is_active: true) }
    let(:station) { create(:therapy_station) }
    let(:iup) { create(:iup, student: student, status: 'active') }

    it 'assigns a goal to a student' do
      params = {
        student_id: student.id,
        goal_id: goal.id,
        station_id: station.id,
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json['student_id']).to eq(student.id)
      expect(json['goal_id']).to eq(goal.id)
    end

    it 'returns 422 when capacity exceeded' do
      # Create 2 existing goals
      2.times do
        create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )
      end

      params = {
        student_id: student.id,
        goal_id: goal.id,
        station_id: station.id,
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('already has 2 goals')
    end
  end

  describe 'PUT /api/v1/goal_assignments/:id/replace' do
    let(:student_goal) { create(:student_goal, status: 'active') }
    let(:new_goal) { create(:goal, is_active: true) }

    it 'replaces a goal' do
      params = { new_goal_id: new_goal.id }

      put "/api/v1/goal_assignments/#{student_goal.id}/replace", params: params, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['archived_goal']['id']).to eq(student_goal.id)
      expect(json['new_goal']['goal_id']).to eq(new_goal.id)
    end
  end
end
