# spec/requests/api/v1/teacher/behavior_assessments_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Teacher::BehaviorAssessments', type: :request do
  let(:user) { create(:user) }
  let(:student) { create(:student) }
  let(:headers) { authenticated_headers(user) }

  describe 'GET /api/v1/teacher/students/:student_id/assessments/behavior' do
    let!(:mass) do
      create(:mass_assessment, student: student, responses: { "M1" => "Always", "M5" => "Usually" }, scores: { sensory: 10, escape: 0, attention: 0, tangible: 0 })
    end
    let!(:fast) do
      create(:fast_assessment, student: student, responses: { "F2" => "Yes", "F6" => "Yes" }, risk_indicators: { sensory: 0, escape: 2, attention: 0, tangible: 0, risk_level: "moderate" })
    end

    it 'returns existing responses, scores, and risk indicators for the student' do
      get "/api/v1/teacher/students/#{student.id}/assessments/behavior", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('success')
      expect(body['data']['massAnswers']).to be_present
      expect(body['data']['fastAnswers']).to be_present
      expect(body['data']['scores']).to be_present
      expect(body['data']['scores']['sensory']).to be >= 10
      expect(body['data']['scores']['escape']).to be >= 2
    end
  end

  describe 'POST /api/v1/teacher/students/:student_id/assessments/behavior' do
    it 'saves MASS (Likert) and FAST (Yes/No) responses and calculates 4 motivation functions and risk indicators' do
      post "/api/v1/teacher/students/#{student.id}/assessments/behavior",
           params: {
             massAnswers: {
               "M1" => "Always",        # Sensory: 6
               "M5" => "Almost Always", # Sensory: 5
               "M2" => "Usually",       # Escape: 4
               "M3" => "Seldom",        # Attention: 2
               "M4" => "Almost Never"   # Tangible: 1
             },
             fastAnswers: {
               "F2" => "Yes",           # Escape
               "F6" => "Yes",           # Escape
               "F3" => "Yes",           # Sensory
               "F1" => "No"
             },
             records: [
               {
                 behavior: "Tantrum",
                 frequency: "3x / day",
                 duration: "10 mins",
                 intensity: "High"
               }
             ],
             status: "draft"
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('success')
      data = body['data']

      expect(data['scores']).to be_present
      # Combined scores:
      # Sensory: 11 (MASS) + 1 (FAST) = 12
      # Escape: 4 (MASS) + 2 (FAST) = 6
      # Attention: 2 (MASS) + 0 (FAST) = 2
      # Tangible: 1 (MASS) + 0 (FAST) = 1
      expect(data['scores']['sensory']).to eq(12)
      expect(data['scores']['escape']).to eq(6)
      expect(data['scores']['attention']).to eq(2)
      expect(data['scores']['tangible']).to eq(1)

      expect(data['dominant_function']).to eq('Sensory')
      expect(data['risk_indicators']).to be_present
      expect(data['risk_indicators']['risk_level']).to be_present
    end
  end
end
