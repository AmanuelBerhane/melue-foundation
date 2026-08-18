# spec/services/charts/trial_distribution_service_spec.rb
require 'rails_helper'

RSpec.describe Charts::TrialDistributionService, type: :service do
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
  let(:prompt_level) { create(:prompt_level, label: 'FP') }

  describe '#call' do
    it 'returns trial distribution data' do
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        prompt_level: prompt_level,
        outcome: 'correct'
      )
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        prompt_level: prompt_level,
        outcome: 'incorrect'
      )

      service = described_class.new(student_goal)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:goal_id]).to eq(student_goal.id)
      expect(result.data[:distribution]).to be_present
    end

    it 'filters by date range' do
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        prompt_level: prompt_level,
        logged_at: 10.days.ago
      )
      create(:trial,
        student_goal: student_goal,
        session_participant: session_participant,
        therapy_session: therapy_session,
        prompt_level: prompt_level,
        logged_at: 2.days.ago
      )

      service = described_class.new(student_goal, 5.days.ago, Time.current)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:distribution].size).to be <= 2
    end

    it 'returns failure if student_goal not found' do
      service = described_class.new(nil)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Student goal not found')
    end
  end
end
