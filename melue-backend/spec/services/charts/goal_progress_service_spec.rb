# spec/services/charts/goal_progress_service_spec.rb
require 'rails_helper'

RSpec.describe Charts::GoalProgressService, type: :service do
  let(:student) { create(:student) }
  let(:student_goal) { create(:student_goal, student: student) }
  let(:therapy_session) { create(:therapy_session) }
  let(:session_participant) do
    create(:session_participant,
      therapy_session: therapy_session,
      student: student,
      current_focus_student_goal: student_goal
    )
  end

  describe '#call' do
    it 'returns goal progress data' do
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        outcome: 'correct',
        logged_at: 2.days.ago
      )
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        outcome: 'incorrect',
        logged_at: 1.day.ago
      )
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        outcome: 'correct',
        logged_at: Time.current
      )

      service = described_class.new(student_goal)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:goal_id]).to eq(student_goal.id)
      expect(result.data[:data_points]).to be_present
    end

    it 'filters by date range' do
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        logged_at: 10.days.ago
      )
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        logged_at: 2.days.ago
      )

      service = described_class.new(student_goal, 5.days.ago, Time.current)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:data_points].size).to be <= 2
    end

    it 'calculates success rate correctly' do
      2.times do
        create(:trial,
          student_goal: student_goal,
          session_participant: session_participant,
          therapy_session: therapy_session,
          outcome: 'correct',
          logged_at: 1.day.ago
        )
      end
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        outcome: 'incorrect',
        logged_at: 1.day.ago
      )

      service = described_class.new(student_goal)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:data_points].first[:success_rate]).to eq(66.67)
    end

    it 'returns failure if student_goal not found' do
      service = described_class.new(nil)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Student goal not found')
    end
  end
end
