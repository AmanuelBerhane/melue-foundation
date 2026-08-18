require 'rails_helper'

RSpec.describe BehaviorIncident, type: :model do
  describe 'associations' do
    it { should belong_to(:student) }
    it { should belong_to(:staff_member).optional }
    it { should belong_to(:therapy_session).optional }
    it { should belong_to(:student_goal).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:behavior_name) }
    it { should validate_presence_of(:behavior_definition) }
    it { should validate_presence_of(:frequency) }
    it { should validate_presence_of(:intensity) }
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:antecedent) }
    it { should validate_presence_of(:consequence) }
    it { should validate_presence_of(:location) }
    it { should validate_presence_of(:occurred_at) }
  end

  describe 'enums' do
    it { should define_enum_for(:frequency).with_values(rarely: 0, occasionally: 1, frequently: 2, very_frequently: 3, constantly: 4) }
    it { should define_enum_for(:intensity).with_values(mild: 0, moderate: 1, severe: 2) }
    it { should define_enum_for(:category).with_values(attention_seeking: 0, safety_concerns: 1, hyperactivity: 2, making_noises: 3, elopement: 4, flopping: 5, difficulty_with_transitions: 6, obsessive: 7, inappropriate: 8) }
  end

  describe '#set_behavior_definition' do
    it 'auto-populates behavior definition' do
      incident = build(:behavior_incident, behavior_name: 'Elopement', behavior_definition: nil)
      incident.set_behavior_definition
      expect(incident.behavior_definition).to eq('Running or wandering away from supervision (moving away at least 5 feet)')
    end

    it 'leaves definition as-is if already present' do
      incident = build(:behavior_incident, behavior_name: 'Elopement', behavior_definition: 'Custom definition')
      incident.set_behavior_definition
      expect(incident.behavior_definition).to eq('Custom definition')
    end
  end

  describe 'scopes' do
    let(:student) { create(:student) }
    let(:student2) { create(:student) }

    before do
      @incident1 = create(:behavior_incident,
        student: student,
        occurred_at: 5.days.ago,
        category: :attention_seeking
      )
      @incident2 = create(:behavior_incident,
        student: student2,
        occurred_at: 15.days.ago,
        category: :attention_seeking
      )
      @incident3 = create(:behavior_incident,
        student: student,
        occurred_at: 3.days.ago,
        category: :safety_concerns
      )
    end

    it '.for_student returns incidents for a specific student' do
      results = BehaviorIncident.for_student(student.id)
      expect(results).to include(@incident1)
      expect(results).to include(@incident3)
      expect(results).not_to include(@incident2)
    end

    it '.for_date_range filters by date range' do
      results = BehaviorIncident.for_date_range(10.days.ago, Date.current)
      expect(results).to include(@incident1)
      expect(results).to include(@incident3)
      expect(results).not_to include(@incident2)
    end

    it '.by_category filters by category' do
      results = BehaviorIncident.by_category(:safety_concerns)
      expect(results).to include(@incident3)
      expect(results).not_to include(@incident1)
      expect(results).not_to include(@incident2)
    end
  end

  describe '#frequency_options' do
    it 'returns frequency options for dropdown' do
      expect(BehaviorIncident.frequency_options).to include('rarely', 'occasionally', 'frequently')
    end
  end

  describe '#intensity_options' do
    it 'returns intensity options for dropdown' do
      expect(BehaviorIncident.intensity_options).to include('mild', 'moderate', 'severe')
    end
  end

  describe '#category_options' do
    it 'returns category options for dropdown' do
      expect(BehaviorIncident.category_options).to include('safety_concerns', 'elopement', 'flopping')
    end
  end

  describe 'default_behavior_definitions' do
    it 'returns default definitions' do
      definitions = BehaviorIncident.default_behavior_definitions
      expect(definitions['Elopement']).to be_present
      expect(definitions['Flopping']).to be_present
    end
  end
end
