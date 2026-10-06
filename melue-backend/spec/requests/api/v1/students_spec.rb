# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Students API', type: :request do
  let(:user) { create(:user) }
  let!(:staff_member) { create(:staff_member, :therapy_coordinator, user: user) }
  let(:headers) { authenticated_headers(user) }

  describe 'POST /api/v1/students' do
    let(:valid_params) do
      {
        first_name: 'Dawit',
        last_name: 'Alemu',
        date_of_birth: 7.years.ago.to_date.to_s,
        program_type: 'regular',
        therapy_group: 'basic',
        diagnosis: 'Autism Spectrum Disorder',
        guardian_name: 'Tigist Alemu',
        guardian_phone: '+251911000000',
        custom_fields: {
          'emergency_contact' => '+251922334455',
          'allergies' => [ 'peanut' ],
          'dietary_restrictions' => 'gluten-free'
        }
      }
    end

    it 'creates a student with in_assessment status, whitelists, persists, and serializes custom_fields' do
      post '/api/v1/students', params: valid_params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json['success']).to be true
      expect(json['data']['status']).to eq('in_assessment')
      expect(json['data']['custom_fields']).to eq({
        'emergency_contact' => '+251922334455',
        'allergies' => [ 'peanut' ],
        'dietary_restrictions' => 'gluten-free'
      })

      student = Student.find(json['data']['id'])
      expect(student.status).to eq('in_assessment')
      expect(student.custom_fields).to eq({
        'emergency_contact' => '+251922334455',
        'allergies' => [ 'peanut' ],
        'dietary_restrictions' => 'gluten-free'
      })
    end

    it 'enforces age-range validations (FR-026)' do
      invalid_params = valid_params.merge(date_of_birth: 2.years.ago.to_date.to_s)

      post '/api/v1/students', params: invalid_params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['success']).to be false
      expect(json['error']).to match(/not appropriate.*basic therapy/i)
    end
  end

  describe 'GET /api/v1/students/:id' do
    let(:student) do
      create(:student,
        first_name: 'Dawit',
        last_name: 'Alemu',
        date_of_birth: 7.years.ago.to_date,
        program_type: 'regular',
        therapy_group: 'basic',
        status: 'in_assessment',
        custom_fields: { 'note' => 'Sensitive to loud noise' }
      )
    end

    it 'returns student profile including custom_fields' do
      get "/api/v1/students/#{student.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['success']).to be true
      expect(json['data']['id']).to eq(student.id)
      expect(json['data']['custom_fields']).to eq({ 'note' => 'Sensitive to loud noise' })
    end
  end

  describe 'PATCH /api/v1/students/:id' do
    let(:student) do
      create(:student,
        first_name: 'Dawit',
        last_name: 'Alemu',
        date_of_birth: 7.years.ago.to_date,
        program_type: 'regular',
        therapy_group: 'basic',
        status: 'in_assessment',
        custom_fields: { 'initial' => 'data' }
      )
    end

    it 'updates custom_fields and returns updated student' do
      patch "/api/v1/students/#{student.id}",
            params: {
              custom_fields: { 'initial' => 'data', 'updated_key' => 'new_val' }
            },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['success']).to be true
      expect(student.reload.custom_fields).to eq({ 'initial' => 'data', 'updated_key' => 'new_val' })
      expect(json['data']['custom_fields']).to eq({ 'initial' => 'data', 'updated_key' => 'new_val' })
    end
  end
end
