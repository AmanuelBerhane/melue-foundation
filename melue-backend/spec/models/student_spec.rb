# spec/models/student_spec.rb
require 'rails_helper'

RSpec.describe Student, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:date_of_birth) }
    it { should validate_presence_of(:guardian_name) }
    it { should validate_presence_of(:guardian_phone) }
    it { should validate_presence_of(:program_type) }
    it { should validate_presence_of(:therapy_group) }
  end

  describe '#age' do
    it 'calculates age correctly' do
      student = Student.new(date_of_birth: 11.years.ago)
      expect(student.age).to eq(11)
    end

    it 'returns nil if date_of_birth is nil' do
      student = Student.new(date_of_birth: nil)
      expect(student.age).to be_nil
    end
  end

  describe '#full_name' do
    it 'combines first and last name' do
      student = Student.new(first_name: 'John', last_name: 'Doe')
      expect(student.full_name).to eq('John Doe')
    end

    it 'includes middle name if present' do
      student = Student.new(
        first_name: 'John',
        middle_name: 'Michael',
        last_name: 'Doe'
      )
      expect(student.full_name).to eq('John Michael Doe')
    end
  end

  describe '#age_warning_for_group?' do
    context 'basic therapy group' do
      it 'returns true for age < 3' do
        student = Student.new(date_of_birth: 2.years.ago, therapy_group: 'basic')
        expect(student.age_warning_for_group?).to be true
      end

      it 'returns false for age between 3 and 12' do
        student = Student.new(date_of_birth: 8.years.ago, therapy_group: 'basic')
        expect(student.age_warning_for_group?).to be false
      end
    end
  end
end
