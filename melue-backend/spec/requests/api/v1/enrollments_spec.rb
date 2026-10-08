# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enrollments API', type: :request do
  let(:user) { create(:user) }
  let!(:staff_member) { create(:staff_member, user: user) }
  let(:headers) { authenticated_headers(user) }

  describe 'POST /api/v1/enrollments' do
    it 'creates a new enrollment with in_assessment status (FR-028)' do
      post '/api/v1/enrollments', headers: headers

      expect(response).to have_http_status(:created)
      expect(json['status']).to eq('in_assessment')
      expect(json['id']).to be_present
      expect(Student.find(json['id']).status).to eq('in_assessment')
    end

    it 'returns 401 if not authenticated' do
      post '/api/v1/enrollments'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'ActiveStorage attachments on enrollments' do
    let(:student) do
      create(:student,
        first_name: 'Sara',
        last_name: 'Alemu',
        date_of_birth: 5.years.ago.to_date,
        program_type: 'regular',
        therapy_group: 'basic',
        status: 'in_assessment'
      )
    end

    describe 'POST /api/v1/enrollments/:id/attach_document' do
      it 'successfully attaches and persists a birth certificate' do
        file = fixture_file_upload(Rails.root.join('spec/fixtures/files/test.pdf'), 'application/pdf') rescue Rack::Test::UploadedFile.new(StringIO.new('%PDF-1.4 test'), 'application/pdf', original_filename: 'birth_cert.pdf')

        post "/api/v1/enrollments/#{student.id}/attach_document",
             params: { document_type: 'birth_certificate', file: file, description: 'Official Birth Certificate' },
             headers: headers

        expect(response).to have_http_status(:created)
        expect(json['message']).to eq('Document attached successfully')
        expect(json['document']['document_type']).to eq('birth_certificate')
        expect(json['document']['url']).to be_present

        doc = student.reload.documents.find_by(document_type: 'birth_certificate')
        expect(doc).to be_present
        expect(doc.file).to be_attached
      end
    end

    describe 'POST /api/v1/enrollments/:id/upload_photo' do
      it 'successfully uploads and persists a headshot photo' do
        file = Rack::Test::UploadedFile.new(StringIO.new('fake jpeg binary'), 'image/jpeg', original_filename: 'headshot.jpg')

        post "/api/v1/enrollments/#{student.id}/upload_photo",
             params: { photo: file },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['photo_url']).to be_present

        expect(student.reload.headshot_photo).to be_attached
        expect(student.headshot).to be_attached
      end
    end

    describe 'POST /api/v1/enrollments/:id/upload_video' do
      it 'successfully uploads and persists a baseline video' do
        file = Rack::Test::UploadedFile.new(StringIO.new('fake mp4 binary'), 'video/mp4', original_filename: 'baseline.mp4')

        post "/api/v1/enrollments/#{student.id}/upload_video",
             params: { video: file },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['video_url']).to be_present

        expect(student.reload.baseline_video).to be_attached
      end
    end
  end
end
