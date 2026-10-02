# spec/requests/api/v1/assessments/mass_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Assessments::Mass', type: :request do
  let(:user) { create(:user) }
  let(:student) { create(:student) }
  let(:headers) { authenticated_headers(user) }

  describe 'POST /api/v1/assessments/mass' do
    it 'creates a new MASS assessment and calculates 4 motivation functions and risk indicators' do
      post '/api/v1/assessments/mass',
           params: {
             student_id: student.id,
             responses: {
               "M1" => "Always",
               "M5" => "Usually",
               "M10" => "Almost Always",
               "M2" => "Seldom",
               "M6" => "Never",
               "M3" => "Half the Time",
               "M4" => "Almost Never"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)

      expect(data['scores']).to be_present
      expect(data['scores']['sensory'].to_i).to eq(15) # 6 + 4 + 5
      expect(data['scores']['escape'].to_i).to eq(2)   # 2 + 0
      expect(data['scores']['attention'].to_i).to eq(3) # 3
      expect(data['scores']['tangible'].to_i).to eq(1)  # 1

      expect(data['risk_indicators']).to be_present
      expect(data['risk_indicators']['risk_level']).to be_present
      expect(data['dominant_function']).to eq('Sensory')
    end
  end

  describe 'PATCH /api/v1/assessments/mass/:id' do
    let!(:assessment) { create(:mass_assessment, student: student, status: 'draft') }

    it 'updates responses and returns calculated 4 motivation functions and risk indicators without dropping them' do
      patch "/api/v1/assessments/mass/#{assessment.id}",
            params: {
              responses: {
                "M2" => "Always",
                "M6" => "Always",
                "M9" => "Almost Always"
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data['scores']).to be_present
      expect(data['scores']['escape'].to_i).to eq(17) # 6 + 6 + 5
      expect(data['dominant_function']).to eq('Escape')
      expect(data['risk_indicators']['risk_level']).to eq('high')
    end
  end

  describe 'POST /api/v1/assessments/mass/:id/submit' do
    let!(:assessment) { create(:mass_assessment, student: student, status: 'draft') }

    it 'submits the assessment and returns completed status with calculated scores' do
      post "/api/v1/assessments/mass/#{assessment.id}/submit",
           params: {
             responses: {
               "M3" => "Always",
               "M7" => "Usually",
               "M11" => "Almost Always"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data['status']).to eq('completed')
      expect(data['scores']['attention'].to_i).to eq(15)
      expect(data['dominant_function']).to eq('Attention')
    end
  end
end
