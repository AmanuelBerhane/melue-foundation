# spec/requests/api/v1/students/behavior_incidents_spec.rb
require 'rails_helper'

RSpec.describe 'Behavior Incidents API', type: :request do
  let(:user) { create(:user, :therapist) }
  let(:staff_member) { create(:staff_member, :program_director, user: user) }
  let(:student) { create(:student) }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
  end

  describe 'GET /api/v1/students/:student_id/behavior_incidents' do
    it 'returns all behavior incidents for a student' do
      create_list(:behavior_incident, 3, student: student, staff_member: staff_member)
      create(:behavior_incident, student: create(:student), staff_member: staff_member)

      get "/api/v1/students/#{student.id}/behavior_incidents", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(3)
    end

    it 'filters by date range' do
      incident1 = create(:behavior_incident, student: student, staff_member: staff_member, occurred_at: 2.days.ago)
      create(:behavior_incident, student: student, staff_member: staff_member, occurred_at: 5.days.ago)

      get "/api/v1/students/#{student.id}/behavior_incidents",
          params: { start_date: 3.days.ago.to_date.to_s, end_date: Time.current.to_date.to_s },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(1)
      expect(json.first['id']).to eq(incident1.id)
    end
  end

  describe 'POST /api/v1/students/:student_id/behavior_incidents' do
    let(:valid_params) do
      {
        behavior_name: 'Aggression',
        behavior_definition: 'Physical aggression towards peers',
        frequency: 'frequently',
        intensity: 'moderate',
        category: 'safety_concerns',
        antecedent: 'Transition between activities',
        consequence: 'Time out',
        location: 'Classroom',
        occurred_at: Time.current.iso8601,
        additional_notes: 'Student was redirected successfully'
      }
    end

    it 'creates a new behavior incident' do
      expect {
        post "/api/v1/students/#{student.id}/behavior_incidents",
             params: valid_params,
             headers: headers
      }.to change(BehaviorIncident, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json['behavior_name']).to eq('Aggression')
      expect(json['student_id']).to eq(student.id)
      expect(json['staff_member_id']).to eq(staff_member.id)
    end

    it 'sets behavior definition automatically if not provided' do
      params = valid_params.except(:behavior_definition)

      post "/api/v1/students/#{student.id}/behavior_incidents",
           params: params,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(json['behavior_definition']).to be_present
    end

    it 'returns validation errors' do
      post "/api/v1/students/#{student.id}/behavior_incidents",
           params: { behavior_name: '' },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to be_present
    end

    it 'returns 404 when student not found' do
      post "/api/v1/students/invalid-id/behavior_incidents",
           params: valid_params,
           headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to eq('Student not found')
    end
  end

  describe 'PUT /api/v1/students/:student_id/behavior_incidents/:id' do
    let(:incident) { create(:behavior_incident, student: student, staff_member: staff_member) }

    it 'updates the incident' do
      params = {
        behavior_name: 'Updated Behavior',
        frequency: 'rarely'
      }

      put "/api/v1/students/#{student.id}/behavior_incidents/#{incident.id}",
          params: params,
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['behavior_name']).to eq('Updated Behavior')
      expect(json['frequency']).to eq('rarely')
    end

    it 'returns 404 when incident not found' do
      put "/api/v1/students/#{student.id}/behavior_incidents/invalid-id",
          params: { behavior_name: 'Updated' },
          headers: headers

      expect(response).to have_http_status(:not_found)
      if response.content_type.include?('application/json')
        expect(json['error']).to be_present
      end
    end
  end

  describe 'DELETE /api/v1/students/:student_id/behavior_incidents/:id' do
    it 'deletes the incident' do
      incident = create(:behavior_incident, student: student, staff_member: staff_member)

      expect {
        delete "/api/v1/students/#{student.id}/behavior_incidents/#{incident.id}",
               headers: headers
      }.to change(BehaviorIncident, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json['message']).to eq('Incident deleted successfully')
    end
  end

  describe 'Authentication' do
    it 'returns unauthorized when not authenticated' do
      # The controller uses authenticate_user! which raises an error when not authenticated
      # This test should pass because the controller will return 401
      get "/api/v1/students/#{student.id}/behavior_incidents"

      # If your app uses a different authentication method, this might return 401
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
