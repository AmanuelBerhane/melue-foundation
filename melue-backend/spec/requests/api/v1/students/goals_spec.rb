# spec/requests/api/v1/students/goals_spec.rb
require 'rails_helper'

RSpec.describe 'Student Goals API', type: :request do
  let(:user) { create(:user, :therapist) }
  let(:staff_member) { create(:staff_member, :program_director, user: user) }
  let(:student) { create(:student) }
  let(:iup) { create(:iup, student: student, status: 'active') }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
  end

  describe 'GET /api/v1/students/:id/goals' do
    it 'returns goal summary for a student' do
      create_list(:student_goal, 3, student: student, iup: iup, status: 'active')
      create(:student_goal, student: student, iup: iup, status: 'mastered')

      get "/api/v1/students/#{student.id}/goals", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['student_id']).to eq(student.id)
      expect(json).to have_key('stations')
      expect(json).to have_key('total_goals')
      expect(json).to have_key('active_goals')
      expect(json).to have_key('mastered_goals')
    end

    it 'includes mastered goals when include_mastered=true' do
      create(:student_goal, student: student, iup: iup, status: 'active')
      create(:student_goal, student: student, iup: iup, status: 'mastered')

      get "/api/v1/students/#{student.id}/goals",
          params: { include_mastered: 'true' },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['mastered_goals']).to eq(1)

      # Check that mastered goals are included in stations
      stations = json['stations']
      all_goals = stations.flat_map { |s| s['goals'] }
      mastered_goals = all_goals.select { |g| g['status'] == 'mastered' }
      expect(mastered_goals.count).to eq(1)
    end

    it 'excludes mastered goals by default' do
      create(:student_goal, student: student, iup: iup, status: 'active')
      create(:student_goal, student: student, iup: iup, status: 'mastered')

      get "/api/v1/students/#{student.id}/goals", headers: headers

      expect(response).to have_http_status(:ok)
      # The total mastered_goals count should still be 1 (for the summary)
      expect(json['mastered_goals']).to eq(1)

      # But mastered goals should NOT be in the stations list
      stations = json['stations']
      all_goals = stations.flat_map { |s| s['goals'] }
      mastered_goals = all_goals.select { |g| g['status'] == 'mastered' }
      expect(mastered_goals.count).to eq(0)
    end

    it 'returns 404 when student not found' do
      get "/api/v1/students/invalid-id/goals", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('Student not found')
    end
  end

  describe 'Authorization' do
    it 'returns 403 when user is not program director' do
      staff_member.update(role: 'teacher')

      get "/api/v1/students/#{student.id}/goals", headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to eq('Unauthorized - Program Director access required')
    end

    it 'returns 401 when not authenticated' do
      get "/api/v1/students/#{student.id}/goals"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Response Structure' do
    it 'returns properly structured JSON response' do
      create(:student_goal, student: student, iup: iup, status: 'active', progress_percent: 75)

      get "/api/v1/students/#{student.id}/goals", headers: headers

      expect(response).to have_http_status(:ok)

      expect(json).to include('student_id', 'stations', 'total_goals', 'mastered_goals', 'active_goals')

      if json['stations'].present?
        station = json['stations'].first
        expect(station).to include('station_id', 'station_name', 'goals')

        if station['goals'].present?
          goal = station['goals'].first
          # Check for either name or goal_name, and either domain or goal_type
          expect(goal.keys).to include('name').or include('goal_name')
          expect(goal.keys).to include('domain').or include('goal_type')
          expect(goal).to include('id', 'status', 'progress_percent')
        end
      end
    end
  end
end
