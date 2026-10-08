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

    it 'calculates 4 motivation functions, category scores, and risk indicators from SCR-TEA-003 F1-F8 responses' do
      fast_assessment.responses = {
        "F1" => "Yes",   # Attention / Social-Positive
        "F2" => true,    # Escape / Social-Negative
        "F3" => "true",  # Sensory / Auto-Positive
        "F4" => "No",    # Sensory / Auto-Negative (false)
        "F5" => 1,       # Sensory / Auto-Positive
        "F6" => "yes",   # Escape / Social-Negative
        "F7" => false,   # Attention / Social-Positive
        "F8" => "1"      # Tangible / Social-Positive
      }
      fast_assessment.save!

      indicators = fast_assessment.calculate_risks!

      expect(indicators[:sensory]).to eq(2)   # F3 + F5
      expect(indicators[:escape]).to eq(2)    # F2 + F6
      expect(indicators[:attention]).to eq(1) # F1
      expect(indicators[:tangible]).to eq(1)  # F8

      expect(fast_assessment.scores[:sensory]).to eq(2)
      expect(fast_assessment.scores[:escape]).to eq(2)
      expect(fast_assessment.scores[:attention]).to eq(1)
      expect(fast_assessment.scores[:tangible]).to eq(1)

      expect(indicators[:category_scores]["Social - Positive"]).to eq(2) # F1 + F8
      expect(indicators[:category_scores]["Social - Negative"]).to eq(2) # F2 + F6
      expect(indicators[:category_scores]["Automatic - Positive"]).to eq(2) # F3 + F5
      expect(indicators[:category_scores]["Automatic - Negative"]).to eq(0)

      expect(indicators[:total]).to be >= 5
      expect(indicators[:risk_level]).to eq("high")
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
