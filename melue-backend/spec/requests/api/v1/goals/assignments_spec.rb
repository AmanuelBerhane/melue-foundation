# spec/requests/api/v1/goals/assignments_spec.rb
require 'rails_helper'

RSpec.describe 'Goal Assignments API - Create', type: :request do
  let(:user) { create(:user, role: :institutional_admin) }
  let(:staff_member) { create(:staff_member, user: user, role: 'program_director') }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
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
      expect(json['status']).to eq('active')
    end

    it 'creates a new IUP if none provided' do
      params = {
        student_id: student.id,
        goal_id: goal.id,
        station_id: station.id
      }

      expect {
        post '/api/v1/goal_assignments', params: params, headers: headers
      }.to change(Iup, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json['iup_id']).to be_present
    end

    it 'returns 422 when capacity exceeded (2 goals per station)' do
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

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to include('already has 2 goals')
    end

    it 'allows assigning goals to different stations up to 2 each' do
      station2 = create(:therapy_station)

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
        station_id: station2.id,
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:created)
      # The model uses therapy_station_id
      expect(json['therapy_station_id']).to eq(station2.id)
    end

    it 'returns 422 if goal is not active' do
      inactive_goal = create(:goal, is_active: false)

      params = {
        student_id: student.id,
        goal_id: inactive_goal.id,
        station_id: station.id,
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to eq('Goal is not active')
    end

    it 'returns 404 if station not found' do
      params = {
        student_id: student.id,
        goal_id: goal.id,
        station_id: 'invalid-id',
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to include('Station not found')
    end

    it 'returns 404 if student not found' do
      params = {
        student_id: 'invalid-id',
        goal_id: goal.id,
        station_id: station.id,
        iup_id: iup.id
      }

      post '/api/v1/goal_assignments', params: params, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to include('Student not found')
    end
  end
end
