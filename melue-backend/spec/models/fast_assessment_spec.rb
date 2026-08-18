# spec/models/fast_assessment_spec.rb
require 'rails_helper'

RSpec.describe FastAssessment, type: :model do
  describe 'associations' do
    it { should belong_to(:student) }
    it { should belong_to(:assessment_cycle).optional }
    it { should belong_to(:teacher).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
  end

  describe '#calculate_risks!' do
    let(:fast_assessment) { create(:fast_assessment) }

    it 'calculates risk indicators from responses' do
      responses = {}
      (1..16).each { |i| responses[i.to_s] = true }
      fast_assessment.responses = responses
      fast_assessment.save

      risk_indicators = fast_assessment.calculate_risks!

      expect(risk_indicators).to have_key(:high_risk_count)
      expect(risk_indicators).to have_key(:moderate_risk_count)
      expect(risk_indicators).to have_key(:risk_level)
    end

    it 'returns low risk for no responses' do
      fast_assessment.responses = {}
      fast_assessment.save

      risk_indicators = fast_assessment.calculate_risks!

      expect(risk_indicators[:risk_level]).to eq('low')
    end
  end

  describe 'risk level methods' do
    let(:fast_assessment) { create(:fast_assessment) }

    it 'identifies high risk' do
      fast_assessment.risk_indicators = { risk_level: 'high' }
      expect(fast_assessment.high_risk?).to be true
      expect(fast_assessment.moderate_risk?).to be false
      expect(fast_assessment.low_risk?).to be false
    end

    it 'identifies moderate risk' do
      fast_assessment.risk_indicators = { risk_level: 'moderate' }
      expect(fast_assessment.high_risk?).to be false
      expect(fast_assessment.moderate_risk?).to be true
      expect(fast_assessment.low_risk?).to be false
    end

    it 'identifies low risk' do
      fast_assessment.risk_indicators = { risk_level: 'low' }
      expect(fast_assessment.high_risk?).to be false
      expect(fast_assessment.moderate_risk?).to be false
      expect(fast_assessment.low_risk?).to be true
    end
  end
end
