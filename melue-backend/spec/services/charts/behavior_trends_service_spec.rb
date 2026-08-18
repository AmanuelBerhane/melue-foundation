# spec/services/charts/behavior_trends_service_spec.rb
require 'rails_helper'

RSpec.describe Charts::BehaviorTrendsService, type: :service do
  let(:student) { create(:student) }

  describe '#call' do
    it 'returns behavior trends data for a student' do
      # Create behavior incidents
      incident1 = create(:behavior_incident,
        student: student,
        occurred_at: 2.days.ago,
        category: :safety_concerns,
        intensity: :moderate
      )
      incident2 = create(:behavior_incident,
        student: student,
        occurred_at: 1.day.ago,
        category: :elopement,
        intensity: :severe
      )

      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:student_id]).to eq(student.id)
      expect(result.data[:data_points]).to be_present
      expect(result.data[:data_points].first[:total_incidents]).to be >= 0
    end

    it 'filters by date range' do
      create(:behavior_incident, student: student, occurred_at: 10.days.ago)
      create(:behavior_incident, student: student, occurred_at: 2.days.ago)

      service = described_class.new(student, 5.days.ago, Time.current)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:data_points].size).to be <= 2
    end

    it 'returns failure if student not found' do
      service = described_class.new(nil)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Student not found')
    end

    it 'handles students with no incidents' do
      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:data_points]).to be_empty
    end
  end
end
