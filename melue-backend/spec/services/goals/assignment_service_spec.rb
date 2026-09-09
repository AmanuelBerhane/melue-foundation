# spec/services/goals/assignment_service_spec.rb
require 'rails_helper'

RSpec.describe Goals::AssignmentService, type: :service do
  let(:student) { create(:student) }
  let(:goal) { create(:goal, is_active: true) }
  let(:station) { create(:therapy_station) }
  let(:iup) { create(:iup, student: student, status: 'active') }

  describe '#call' do
    it 'assigns a goal to a student' do
      service = described_class.new(student, goal.id, station.id, iup.id)
      result = service.call

      expect(result.success?).to be true
      expect(result.data).to be_a(StudentGoal)
      expect(result.data.student).to eq(student)
      expect(result.data.goal).to eq(goal)
    end

    it 'prevents exceeding the 2 goal limit per station' do
      # Create 2 existing goals
      2.times do
        create(:student_goal,
          student: student,
          iup: iup,
          therapy_station: station,
          status: 'active'
        )
      end

      service = described_class.new(student, goal.id, station.id, iup.id)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('already has 2 goals')
    end

    it 'creates a new IUP if none provided' do
      service = described_class.new(student, goal.id, station.id)
      result = service.call

      expect(result.success?).to be true
      expect(result.data.iup).to be_present
      expect(result.data.iup.status).to eq('active')
    end

    it 'fails if goal is not active' do
      inactive_goal = create(:goal, is_active: false)
      service = described_class.new(student, inactive_goal.id, station.id, iup.id)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Goal not found')
    end
  end
end
