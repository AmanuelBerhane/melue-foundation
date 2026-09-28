# spec/services/assessments/mass_service_spec.rb
require 'rails_helper'

RSpec.describe Assessments::MassService, type: :service do
  let(:student) { create(:student) }

  describe '#start' do
    it 'creates a new MASS assessment' do
      service = described_class.new(student, {}, nil)
      result = service.start

      expect(result.success?).to be true
      expect(result.data).to be_a(MassAssessment)
      expect(result.data.status).to eq('draft')
    end
  end

  describe '#calculate_scores!' do
    it 'calculates function scores from responses' do
      assessment = create(:mass_assessment, student: student)
      responses = {}
      (1..20).each { |i| responses[i.to_s] = rand(0..6) }
      assessment.responses = responses
      assessment.save

      scores = assessment.calculate_scores!

      expect(scores).to have_key(:sensory)
      expect(scores).to have_key(:escape)
      expect(scores).to have_key(:attention)
      expect(scores).to have_key(:tangible)
      expect(scores.values.all? { |v| v >= 0 }).to be true
    end
  end
end
