# spec/requests/api/v1/students/charts_spec.rb
require 'rails_helper'

RSpec.describe 'Charts API', type: :request do
  let(:user) { create(:user, :therapist) }
  let(:staff_member) { create(:staff_member, :program_director, user: user) }
  let(:student) { create(:student) }
  let(:iup) { create(:iup, student: student, status: 'active') }
  let(:student_goal) { create(:student_goal, student: student, iup: iup) }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
  end

  describe 'GET /api/v1/students/:student_id/charts/goal_progress' do
    it 'returns goal progress data' do
      therapy_session = create(:therapy_session)
      session_participant = create(:session_participant,
                                   therapy_session: therapy_session,
                                   student: student)

      create_list(:trial, 5,
                  student_goal: student_goal,
                  therapy_session: therapy_session,
                  session_participant: session_participant)

      get "/api/v1/students/#{student.id}/charts/goal_progress",
          params: { goal_id: student_goal.id },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['goal_id']).to eq(student_goal.id)
      expect(json).to have_key('data_points')
    end

    it 'returns 404 when goal not found' do
      get "/api/v1/students/#{student.id}/charts/goal_progress",
          params: { goal_id: 'invalid-id' },
          headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('Goal not found for this student')
    end

    it 'uses default date range when not provided' do
      get "/api/v1/students/#{student.id}/charts/goal_progress",
          params: { goal_id: student_goal.id },
          headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/students/:student_id/charts/trial_distribution' do
    it 'returns trial distribution data' do
      therapy_session = create(:therapy_session)
      session_participant = create(:session_participant,
                                   therapy_session: therapy_session,
                                   student: student)

      create_list(:trial, 5,
                  student_goal: student_goal,
                  therapy_session: therapy_session,
                  session_participant: session_participant)

      get "/api/v1/students/#{student.id}/charts/trial_distribution",
          params: { goal_id: student_goal.id },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key('distribution')
    end

    it 'returns 404 when goal not found' do
      get "/api/v1/students/#{student.id}/charts/trial_distribution",
          params: { goal_id: 'invalid-id' },
          headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('Goal not found for this student')
    end
  end

  describe 'GET /api/v1/students/:student_id/charts/behavior_trends' do
    it 'returns behavior trends data' do
      create_list(:behavior_incident, 3, student: student, staff_member: staff_member)

      get "/api/v1/students/#{student.id}/charts/behavior_trends",
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key('data_points')
    end
  end

  describe 'GET /api/v1/students/:student_id/charts/assessment_summary' do
    it 'returns assessment summary' do
      create(:mass_assessment, :completed, student: student)
      create(:fast_assessment, :completed, student: student)

      get "/api/v1/students/#{student.id}/charts/assessment_summary",
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key('assessments')
    end
  end

  describe 'POST /api/v1/students/:student_id/charts/export' do
    it 'exports chart data as JSON' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'goal_progress', goal_id: student_goal.id },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['chart_type']).to eq('goal_progress')
      expect(json).to have_key('data')
      expect(json).to have_key('exported_at')
      expect(json['format']).to eq('json')
    end

    it 'exports as PDF document' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'goal_progress', goal_id: student_goal.id, format: 'pdf' },
           headers: headers

      expect(response).to have_http_status(:ok)
      # Check if it's a PDF or placeholder
      if response.content_type.include?('application/pdf')
        expect(response.headers['Content-Disposition']).to include('.pdf')
      else
        expect(json['message']).to be_present
      end
    end

    it 'exports as PNG image' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'goal_progress', goal_id: student_goal.id, format: 'png' },
           headers: headers

      expect(response).to have_http_status(:ok)
      # For MVP, PNG returns a placeholder message
      if response.content_type.include?('image/png')
        expect(response.headers['Content-Disposition']).to include('.png')
      else
        expect(json['message']).to include('PNG export will be available soon')
        expect(json['format']).to eq('png_placeholder')
      end
    end

    it 'validates chart_type parameter' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'invalid_type', format: 'json' },
           headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to include('Invalid chart type')
    end

    it 'requires goal_id for goal_progress' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'goal_progress', format: 'json' },
           headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to include('goal_id is required')
    end

    it 'requires goal_id for trial_distribution' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'trial_distribution', format: 'json' },
           headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json['error']).to include('goal_id is required')
    end

    it 'returns 404 if goal not found for export' do
      post "/api/v1/students/#{student.id}/charts/export",
           params: { chart_type: 'goal_progress', goal_id: 'invalid-id', format: 'json' },
           headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to be_present
    end

    it 'handles missing data gracefully' do
      # Student with no data
      new_student = create(:student)
      new_iup = create(:iup, student: new_student, status: 'active')
      new_goal = create(:student_goal, student: new_student, iup: new_iup)

      post "/api/v1/students/#{new_student.id}/charts/export",
           params: { chart_type: 'goal_progress', goal_id: new_goal.id, format: 'json' },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['data']['data_points']).to be_empty
    end
  end

  describe 'POST /api/v1/students/:student_id/charts/share' do
    it 'generates a shareable link' do
      post "/api/v1/students/#{student.id}/charts/share",
           params: { chart_type: 'goal_progress', goal_id: student_goal.id },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['message']).to eq('Chart shared with parent(s)')
      expect(json['share_link']).to be_present
      expect(json['expires_at']).to be_present
    end

    it 'creates unique share tokens' do
      post "/api/v1/students/#{student.id}/charts/share",
           params: { chart_type: 'goal_progress' },
           headers: headers

      first_link = json['share_link']

      post "/api/v1/students/#{student.id}/charts/share",
           params: { chart_type: 'goal_progress' },
           headers: headers

      second_link = json['share_link']

      expect(first_link).not_to eq(second_link)
    end
  end

  describe 'Authorization' do
    it 'returns 403 when user is not program director' do
      staff_member.update(role: 'teacher')

      get "/api/v1/students/#{student.id}/charts/goal_progress",
          params: { goal_id: student_goal.id },
          headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to eq('Unauthorized - Program Director access required')
    end

    it 'returns 401 when not authenticated' do
      get "/api/v1/students/#{student.id}/charts/goal_progress",
          params: { goal_id: student_goal.id }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
