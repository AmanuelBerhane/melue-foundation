# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Coordinator Students API', type: :request do
  let(:coordinator_user) { create(:user) }
  let!(:staff_member) { create(:staff_member, user: coordinator_user, role: 'therapy_coordinator') }
  let(:headers) { authenticated_headers(coordinator_user) }

  describe 'POST /api/v1/coordinator/students' do
    let(:valid_params) do
      {
        firstName: 'Dawit',
        lastName: 'Alemu',
        dateOfBirth: 6.years.ago.to_date.to_s,
        programType: 'Regular',
        therapyGroup: 'Basic Therapy',
        diagnosis: 'Autism Spectrum Disorder',
        parentName: 'Tigist Alemu',
        parentPhone: '+251911000000',
        parentEmail: 'tigist@example.com',
        custom_fields: {
          'emergency_contact' => '+251922334455',
          'allergies' => [ 'peanut', 'dairy' ],
          'dietary_restrictions' => 'gluten-free'
        }
      }
    end

    it 'creates a student with in_assessment status and persists custom_fields' do
      post '/api/v1/coordinator/students', params: valid_params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json['status']).to eq('In assessment')
      expect(json['fullName']).to eq('Dawit Alemu')
      expect(json['studentId']).to match(/\AMEL-\d{4,}-\d{2}\z/)
      expect(json['student_id']).to eq(json['studentId'])
      expect(json['custom_fields']).to eq({
        'emergency_contact' => '+251922334455',
        'allergies' => [ 'peanut', 'dairy' ],
        'dietary_restrictions' => 'gluten-free'
      })

      student = Student.find(json['id'])
      expect(student.status).to eq('in_assessment')
      expect(student.custom_fields).to eq({
        'emergency_contact' => '+251922334455',
        'allergies' => [ 'peanut', 'dairy' ],
        'dietary_restrictions' => 'gluten-free'
      })
    end

    it 'accepts snake_case parameters including custom_fields' do
      snake_params = {
        first_name: 'Sara',
        last_name: 'Wolde',
        date_of_birth: 15.years.ago.to_date.to_s,
        program_type: 'regular',
        therapy_group: 'functional_living',
        guardian_name: 'Hana Wolde',
        guardian_phone: '+251922000000',
        custom_fields: { 'transportation_route' => 'Route B' }
      }

      post '/api/v1/coordinator/students', params: snake_params, headers: headers

      expect(response).to have_http_status(:created)
      student = Student.find(json['id'])
      expect(student.status).to eq('in_assessment')
      expect(student.therapy_group).to eq('functional_living')
      expect(student.custom_fields).to eq({ 'transportation_route' => 'Route B' })
    end

    it 'enforces age-range validation for Basic Therapy via RegisterService (FR-026)' do
      invalid_age_params = valid_params.merge(dateOfBirth: 2.years.ago.to_date.to_s)

      post '/api/v1/coordinator/students', params: invalid_age_params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['errors'].join).to match(/not appropriate.*basic therapy/i)
      expect(Student.find_by(first_name: 'Dawit')).to be_nil
    end

    it 'enforces age-range validation for Functional Living Skills via RegisterService (FR-026)' do
      invalid_fls_params = valid_params.merge(
        therapyGroup: 'Functional Living Skills',
        dateOfBirth: 10.years.ago.to_date.to_s # age 10 is too young for FLS (13–19)
      )

      post '/api/v1/coordinator/students', params: invalid_fls_params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['errors'].join).to match(/not appropriate.*functional living skills/i)
    end
  end

  describe 'GET /api/v1/coordinator/students' do
    let!(:student1) { create(:student, first_name: 'Helen', last_name: 'Tesfaye') }
    let!(:student2) { create(:student, first_name: 'Solomon', last_name: 'Girma') }

    it 'returns studentId and student_id in the listing' do
      get '/api/v1/coordinator/students', headers: headers

      expect(response).to have_http_status(:ok)
      first_item = json.find { |s| s['id'] == student1.id }
      expect(first_item['studentId']).to eq(student1.student_id)
      expect(first_item['student_id']).to eq(student1.student_id)
    end

    it 'supports searching by studentId' do
      get "/api/v1/coordinator/students?search=#{student1.student_id}", headers: headers

      expect(response).to have_http_status(:ok)
      ids = json.map { |s| s['studentId'] }
      expect(ids).to include(student1.student_id)
      expect(ids).not_to include(student2.student_id)
    end
  end

  describe 'GET /api/v1/coordinator/students/:id/profile' do
    let(:student) do
      create(:student,
        first_name: 'Yonas',
        last_name: 'Kebede',
        date_of_birth: 7.years.ago.to_date,
        program_type: 'regular',
        therapy_group: 'basic',
        status: 'in_assessment',
        diagnosis: 'ASD Level 2',
        custom_fields: {
          'preferred_language' => 'Amharic',
          'medical_alerts' => 'Asthma inhaler in backpack'
        }
      )
    end

    before do
      # Attach documents
      birth_cert = student.documents.build(
        document_type: 'birth_certificate',
        description: 'Official birth certificate copy'
      )
      birth_cert.file.attach(
        io: StringIO.new('%PDF-1.4 birth certificate'),
        filename: 'birth_cert.pdf',
        content_type: 'application/pdf'
      )
      birth_cert.save!

      diag_paper = student.documents.build(
        document_type: 'diagnosis_paper',
        description: 'Clinical neuropsychiatric evaluation'
      )
      diag_paper.file.attach(
        io: StringIO.new('%PDF-1.4 diagnosis paper'),
        filename: 'diagnosis_paper.pdf',
        content_type: 'application/pdf'
      )
      diag_paper.save!

      # Attach photo
      student.headshot_photo.attach(
        io: StringIO.new('fake image bytes'),
        filename: 'yonas.png',
        content_type: 'image/png'
      )
    end

    it 'returns custom_fields and live document attachments so profile cards are populated' do
      get "/api/v1/coordinator/students/#{student.id}/profile", headers: headers

      expect(response).to have_http_status(:ok)

      expect(json['id']).to eq(student.id)
      expect(json['fullName']).to eq('Yonas Kebede')
      expect(json['custom_fields']).to eq({
        'preferred_language' => 'Amharic',
        'medical_alerts' => 'Asthma inhaler in backpack'
      })

      # Documents list
      expect(json['documents'].size).to eq(2)

      # Birth certificate document data
      expect(json['birth_certificate']).to be_present
      expect(json['birth_certificate']['filename']).to eq('birth_cert.pdf')
      expect(json['birth_certificate']['url']).to be_present
      expect(json['birthCertificate']).to be_present
      expect(json['birthCertificate']['url']).to be_present

      # Diagnosis paper document data
      expect(json['diagnosis_paper']).to be_present
      expect(json['diagnosis_paper']['filename']).to eq('diagnosis_paper.pdf')
      expect(json['diagnosis_paper']['url']).to be_present
      expect(json['diagnosisPaper']).to be_present
      expect(json['diagnosisPaper']['url']).to be_present

      # Photo
      expect(json['hasPhoto']).to be true
      expect(json['photoUrl']).to be_present
    end

    it 'allows fetching profile using studentId instead of UUID' do
      get "/api/v1/coordinator/students/#{CGI.escape(student.student_id)}/profile", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['id']).to eq(student.id)
      expect(json['studentId']).to eq(student.student_id)
      expect(json['fullName']).to eq('Yonas Kebede')
    end
  end

  describe 'PATCH /api/v1/coordinator/students/:id/profile' do
    let(:student) do
      create(:student,
        first_name: 'Yonas',
        last_name: 'Kebede',
        date_of_birth: 7.years.ago.to_date,
        program_type: 'regular',
        therapy_group: 'basic',
        status: 'in_assessment'
      )
    end

    it 'updates custom_fields and profile attributes' do
      patch "/api/v1/coordinator/students/#{student.id}/profile",
            params: {
              diagnosis: 'Updated Diagnosis',
              custom_fields: { 'special_needs' => 'Noise-cancelling headphones' }
            },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(student.reload.diagnosis).to eq('Updated Diagnosis')
      expect(student.custom_fields).to eq({ 'special_needs' => 'Noise-cancelling headphones' })
    end
  end
end
