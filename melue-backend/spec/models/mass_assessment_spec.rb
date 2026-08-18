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
      mass_assessment = create(:mass_assessment, scores: { sensory: 15, escape: 10, attention: 12, tangible: 8 })

      result = mass_assessment.highest_function
      expect(result.first.to_sym).to eq(:sensory)
      expect(result.last).to eq(15)
    end
  end
end
