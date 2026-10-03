# spec/models/mass_assessment_spec.rb
require 'rails_helper'

RSpec.describe MassAssessment, type: :model do
  describe 'associations' do
    it { should belong_to(:student) }
    it { should belong_to(:assessment_cycle).optional }
    it { should belong_to(:teacher).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
  end

  describe '#calculate_scores!' do
    let(:mass_assessment) { create(:mass_assessment) }

    it 'calculates function scores from responses' do
      responses = {}
      (1..20).each { |i| responses[i.to_s] = rand(0..6) }
      mass_assessment.responses = responses
      mass_assessment.save

      scores = mass_assessment.calculate_scores!

      expect(scores).to have_key(:sensory)
      expect(scores).to have_key(:escape)
      expect(scores).to have_key(:attention)
      expect(scores).to have_key(:tangible)
    end

    it 'returns zero for unanswered questions' do
      mass_assessment.responses = {}
      mass_assessment.save

      scores = mass_assessment.calculate_scores!

      expect(scores[:sensory]).to eq(0)
      expect(scores[:escape]).to eq(0)
      expect(scores[:attention]).to eq(0)
      expect(scores[:tangible]).to eq(0)
    end
  end

  describe '#function_scores' do
    let(:mass_assessment) { create(:mass_assessment, scores: { sensory: 15, escape: 10, attention: 12, tangible: 8 }) }

    it 'returns the stored scores' do
      expect(mass_assessment.function_scores[:sensory]).to eq(15)
      expect(mass_assessment.function_scores[:escape]).to eq(10)
    end

    it 'calculates if scores are not present' do
      mass_assessment.scores = nil
      mass_assessment.save

      # Set some responses so calculation returns something
      responses = {}
      (1..20).each { |i| responses[i.to_s] = 3 }
      mass_assessment.responses = responses
      mass_assessment.save

      expect(mass_assessment.function_scores).to be_present
      expect(mass_assessment.function_scores[:sensory]).to eq(15)
    end
  end

  describe '#highest_function' do
    let(:mass_assessment) { create(:mass_assessment, scores: { sensory: 15, escape: 10, attention: 12, tangible: 8 }) }

    it 'returns the highest scoring function' do
      result = mass_assessment.highest_function
      expect(result.first.to_sym).to eq(:sensory)
      expect(result.last).to eq(15)
    end
  end

  describe '#calculate_scores! with SCR-TEA-003 Likert responses' do
    let(:mass_assessment) { create(:mass_assessment) }

    it 'correctly parses Likert strings (0-6) and maps M1-M12 to the 4 motivation functions' do
      mass_assessment.responses = {
        "M1" => "Always",         # Sensory: 6
        "M5" => "Almost Always",  # Sensory: 5
        "M10" => "Usually",       # Sensory: 4 -> total = 15
        "M2" => "Half the Time",  # Escape: 3
        "M6" => "Seldom",         # Escape: 2
        "M9" => "Almost Never",   # Escape: 1 -> total = 6
        "M3" => "Never",          # Attention: 0
        "M7" => "Seldom",         # Attention: 2
        "M11" => "Seldom",        # Attention: 2 -> total = 4
        "M4" => "Half the Time",  # Tangible: 3
        "M8" => "Half the Time",  # Tangible: 3
        "M12" => "Seldom"         # Tangible: 2 -> total = 8
      }
      mass_assessment.save!

      scores = mass_assessment.calculate_scores!

      expect(scores[:sensory]).to eq(15)
      expect(scores[:escape]).to eq(6)
      expect(scores[:attention]).to eq(4)
      expect(scores[:tangible]).to eq(8)

      expect(mass_assessment.dominant_function).to eq("Sensory")
      expect(mass_assessment.risk_indicators[:risk_level]).to eq("high")
      expect(mass_assessment.risk_indicators[:dominant_function]).to eq("Sensory")
    end
  end

  describe '#risk_indicators' do
    let(:mass_assessment) { create(:mass_assessment, scores: { sensory: 14, escape: 4, attention: 2, tangible: 5 }) }

    it 'returns risk indicators including total, level, and dominant function' do
      indicators = mass_assessment.risk_indicators
      expect(indicators[:total]).to eq(25)
      expect(indicators[:risk_level]).to eq("high")
      expect(indicators[:dominant_function]).to eq("Sensory")
    end
  end
end
