# spec/requests/api/v1/staff_scheduling_spec.rb
require 'rails_helper'

RSpec.describe 'Staff Scheduling API', type: :request do
  # Use valid role from User model
  let(:user) { create(:user, role: 'institutional_admin') }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/staff_scheduling' do
    it 'returns schedule grid' do
      get '/api/v1/staff_scheduling', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['schedule']).to be_an(Array)
    end

    it 'filters by date range' do
      get '/api/v1/staff_scheduling',
          params: { start_date: Date.current.beginning_of_week, end_date: Date.current.end_of_week },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['meta']['start_date']).to be_present
    end

    it 'returns 401 if not authenticated' do
      get '/api/v1/staff_scheduling'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/staff_scheduling/capacity' do
    let(:teacher) { create(:staff_member, role: 'teacher') }

    it 'returns capacity for a teacher' do
      get '/api/v1/staff_scheduling/capacity',
          params: { teacher_id: teacher.id },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['max']).to be_present
      expect(json['current']).to be_present
      expect(json['available']).to be_present
    end
  end

  describe 'GET /api/v1/staff_scheduling/teacher_schedule' do
    let(:teacher) { create(:staff_member, role: 'teacher') }

    it 'returns a teacher schedule' do
      get '/api/v1/staff_scheduling/teacher_schedule',
          params: { id: teacher.id },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['teacher']['id']).to eq(teacher.id)
    end

    it 'returns 404 for non-existent teacher' do
      get '/api/v1/staff_scheduling/teacher_schedule',
          params: { id: 99999 },
          headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/assignments' do
    let(:teacher) { create(:staff_member, role: 'teacher') }
    let(:student) { create(:student) }
    let(:block) { create(:session_block_definition) }
    let(:station) { create(:therapy_station) }
    let(:room) { create(:therapy_room, therapy_station: station) }

    it 'creates a new assignment' do
      params = {
        assignment: {
          teacher_id: teacher.id,
          student_id: student.id,
          session_block_definition_id: block.id,
          therapy_station_id: station.id,
          therapy_room_id: room.id,
          scheduled_date: Date.current
        }
      }

      post '/api/v1/assignments', params: params, headers: headers

      expect(response).to have_http_status(:created)
      expect(json['teacher_id']).to eq(teacher.id)
      expect(json['student_id']).to eq(student.id)
    end

    it 'returns 422 if capacity exceeded' do
      config = SessionScheduleConfig.instance
      config.update!(staff_to_student_capacity: 1)

      # Create existing assignment
      other_student = create(:student)
      create(:teacher_student_assignment,
        teacher: teacher,
        student: other_student,
        scheduled_date: Date.current,
        session_block_definition: block
      )

      params = {
        assignment: {
          teacher_id: teacher.id,
          student_id: student.id,
          session_block_definition_id: block.id,
          scheduled_date: Date.current
        }
      }

      post '/api/v1/assignments', params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('capacity limit')
    end

    it 'returns 422 if student is double-booked' do
      # Create existing assignment for same student
      other_teacher = create(:staff_member, role: 'teacher')
      create(:teacher_student_assignment,
        teacher: other_teacher,
        student: student,
        scheduled_date: Date.current,
        session_block_definition: block
      )

      params = {
        assignment: {
          teacher_id: teacher.id,
          student_id: student.id,
          session_block_definition_id: block.id,
          scheduled_date: Date.current
        }
      }

      post '/api/v1/assignments', params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('already assigned')
    end
  end

  describe 'PUT /api/v1/assignments/:id' do
    let(:teacher) { create(:staff_member, role: 'teacher') }
    let(:student) { create(:student) }
    let(:block) { create(:session_block_definition) }
    let(:assignment) do
      create(:teacher_student_assignment,
        teacher: teacher,
        student: student,
        scheduled_date: Date.current,
        session_block_definition: block
      )
    end

    it 'updates an assignment' do
      new_student = create(:student)
      params = {
        assignment: {
          student_id: new_student.id
        }
      }

      put "/api/v1/assignments/#{assignment.id}", params: params, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['student_id']).to eq(new_student.id)
    end

    it 'returns 404 for non-existent assignment' do
      params = { assignment: { status: 'cancelled' } }
      put '/api/v1/assignments/99999', params: params, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/assignments/:id' do
    let(:assignment) { create(:teacher_student_assignment) }

    it 'deletes an assignment' do
      delete "/api/v1/assignments/#{assignment.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['message']).to include('deleted')
    end
  end
end
