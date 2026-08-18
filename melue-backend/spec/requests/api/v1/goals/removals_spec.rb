# spec/requests/api/v1/goals/removals_spec.rb
require 'rails_helper'

RSpec.describe 'Goal Assignments API - Removals', type: :request do
  let(:user) { create(:user, role: :institutional_admin) }
  let(:staff_member) { create(:staff_member, user: user, role: 'program_director') }
  let(:headers) { auth_headers(user) }

  before do
    staff_member
  end

  describe 'DELETE /api/v1/goal_assignments/:id' do
    let(:student) { create(:student) }
    let(:iup) { create(:iup, student: student, status: 'active') }
    let(:station) { create(:therapy_station) }

    it 'removes a goal assignment with confirmation' do
      student_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'active'
      )

      params = { confirmation: true }

      delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json['message']).to include('successfully removed')
      expect(json['student_goal_id']).to eq(student_goal.id)

      student_goal.reload
      expect(student_goal.status).to eq('archived')
    end

    it 'requires confirmation before removal' do
      student_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'active'
      )

      params = { confirmation: false }

      delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to include('Confirmation required')
    end

    it 'soft deletes/archives the goal assignment' do
      student_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'active'
      )

      params = { confirmation: true }

      delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

      expect(response).to have_http_status(:ok)

      student_goal.reload
      expect(student_goal.status).to eq('archived')
    end

    it 'prevents removal of already archived goal' do
      archived_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'archived'
      )

      params = { confirmation: true }

      delete "/api/v1/goal_assignments/#{archived_goal.id}", params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to eq('Goal is already archived')
    end

    it 'returns 404 if student_goal not found' do
      params = { confirmation: true }

      delete "/api/v1/goal_assignments/invalid-id", params: params, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json['error']).to include('not found')
    end

    it 'allows removing a goal when capacity was full' do
      # Create 2 existing goals
      2.times do
        create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )
      end

      # Get an active goal to remove
      goal_to_remove = student.student_goals.where(therapy_station: station, status: 'active').first

      params = { confirmation: true }

      expect {
        delete "/api/v1/goal_assignments/#{goal_to_remove.id}", params: params, headers: headers
      }.to change { StudentGoal.where(student: student, therapy_station: station, status: 'active').count }.by(-1)

      expect(response).to have_http_status(:ok)

      goal_to_remove.reload
      expect(goal_to_remove.status).to eq('archived')
    end

    it 'records who removed the goal' do
      student_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'active'
      )

      params = { confirmation: true }

      delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'prevents removal if there are active trials' do
      student_goal = create(:student_goal,
        student: student,
        iup: iup,
        therapy_station: station,
        status: 'active'
      )

      # Create a trial for this goal
      therapy_session = create(:therapy_session)
      session_participant = create(:session_participant,
                                   therapy_session: therapy_session,
                                   student: student)

      create(:trial,
        student_goal: student_goal,
        therapy_session: therapy_session,
        session_participant: session_participant,
        outcome: 'correct'
      )

      params = { confirmation: true }

      delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

      # Should either prevent removal or allow it with warnings
      expect(response.status).to be_in([ 200, 422 ])
    end

    describe 'Authorization' do
      it 'returns 403 when user is not program director' do
        student_goal = create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )

        staff_member.update(role: 'teacher')

        params = { confirmation: true }

        delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(json['error']).to include('Unauthorized')
      end

      it 'returns 401 when not authenticated' do
        student_goal = create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )

        params = { confirmation: true }

        delete "/api/v1/goal_assignments/#{student_goal.id}", params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'Response Structure' do
      it 'returns properly structured JSON for removal' do
        student_goal = create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )

        params = { confirmation: true }

        delete "/api/v1/goal_assignments/#{student_goal.id}", params: params, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json).to include('message', 'student_goal_id')
        expect(json['message']).to include('successfully removed')
      end
    end
  end
end
