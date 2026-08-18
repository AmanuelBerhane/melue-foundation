# spec/services/charts/assessment_summary_service_spec.rb
require 'rails_helper'

RSpec.describe Charts::AssessmentSummaryService, type: :service do
  let(:student) { create(:student) }

  describe '#call' do
    it 'returns assessment summary for a student' do
      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:student_id]).to eq(student.id)
      expect(result.data[:assessments]).to have_key(:preference)
      expect(result.data[:assessments]).to have_key(:skills)
      expect(result.data[:assessments]).to have_key(:behavior)
    end

    it 'includes preference assessment data when available' do
      assessment_cycle = create(:assessment_cycle, student: student)
      preference = create(:preference_assessment,
        assessment_cycle: assessment_cycle,
        status: 'submitted',
        submitted_at: Time.current
      )
      create(:preference_observation,
        preference_assessment: preference,
        rank: 1,
        duration_seconds: 120,
        frequency_count: 3
      )

      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:assessments][:preference][:available]).to be true
      expect(result.data[:assessments][:preference][:top_preferences]).to be_present
    end

    it 'includes MASS assessment data when available' do
      create(:mass_assessment, :completed, student: student)

      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:assessments][:behavior][:available]).to be true
      expect(result.data[:assessments][:behavior][:mass]).to be_present
    end

    it 'includes FAST assessment data when available' do
      create(:fast_assessment, :completed, student: student)

      service = described_class.new(student)
      result = service.call

      expect(result.success?).to be true
      expect(result.data[:assessments][:behavior][:available]).to be true
      expect(result.data[:assessments][:behavior][:fast]).to be_present
    end

    it 'returns failure if student not found' do
      service = described_class.new(nil)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Student not found')
    end
  end
end
