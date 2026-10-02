# spec/requests/api/v1/assessments/fast_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Assessments::Fast', type: :request do
  let(:user) { create(:user) }
  let(:student) { create(:student) }
  let(:headers) { authenticated_headers(user) }

  describe 'POST /api/v1/assessments/fast' do
    it 'creates a new FAST assessment and calculates 4 motivation functions and risk indicators' do
      post '/api/v1/assessments/fast',
           params: {
             student_id: student.id,
             responses: {
               "F1" => "Yes",
               "F2" => "No",
               "F3" => "Yes",
               "F4" => "No",
               "F5" => "Yes",
               "F6" => "No",
               "F7" => "Yes",
               "F8" => "No"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)

      expect(data['risk_indicators']).to be_present
      expect(data['risk_indicators']['sensory']).to eq(2)   # F3 + F5
      expect(data['risk_indicators']['attention']).to eq(2) # F1 + F7
      expect(data['risk_indicators']['escape']).to eq(0)
      expect(data['risk_indicators']['tangible']).to eq(0)
      expect(data['scores']).to be_present
      expect(data['scores']['sensory']).to eq(2)
      expect(data['scores']['attention']).to eq(2)
      expect(data['risk_indicators']['risk_level']).to be_present
    end
  end

  describe 'PATCH /api/v1/assessments/fast/:id' do
    let!(:assessment) { create(:fast_assessment, student: student, status: 'draft') }

    it 'updates responses and returns calculated 4 motivation functions and risk indicators' do
      patch "/api/v1/assessments/fast/#{assessment.id}",
            params: {
              responses: {
                "F2" => "Yes",
                "F6" => "Yes"
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data['risk_indicators']).to be_present
      expect(data['risk_indicators']['escape']).to eq(2)
      expect(data['scores']['escape']).to eq(2)
      expect(data['hypothesized_function']).to eq('Escape')
    end
  end

  describe 'POST /api/v1/assessments/fast/:id/submit' do
    let!(:assessment) { create(:fast_assessment, student: student, status: 'draft') }

    it 'submits the assessment and returns completed status with calculated risk indicators' do
      post "/api/v1/assessments/fast/#{assessment.id}/submit",
           params: {
             responses: {
               "F1" => "Yes",
               "F2" => "Yes",
               "F6" => "Yes",
               "F7" => "Yes",
               "F8" => "Yes"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data['status']).to eq('completed')
      expect(data['risk_indicators']['total']).to be >= 5
      expect(data['risk_indicators']['risk_level']).to eq('high')
    end
  end
end
