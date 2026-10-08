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

  describe 'custom_fields' do
    it 'defaults to empty hash' do
      student = Student.new
      expect(student.custom_fields).to eq({})
    end

    it 'persists arbitrary jsonb data' do
      student = build(:student, custom_fields: { 'emergency_contact' => '123-456', 'tags' => [ 'new' ] })
      student.save!
      expect(student.reload.custom_fields).to eq({ 'emergency_contact' => '123-456', 'tags' => [ 'new' ] })
    end

    it 'is invalid if custom_fields is not a hash' do
      student = build(:student)
      student.custom_fields = 'not a hash'
      expect(student).not_to be_valid
      expect(student.errors[:custom_fields]).to include('must be an object')
    end
  end

  describe '#attached_photo' do
    let(:student) { create(:student) }

    it 'returns headshot_photo if attached' do
      student.headshot_photo.attach(io: StringIO.new('data'), filename: 'photo.jpg', content_type: 'image/jpeg')
      expect(student.attached_photo).to eq(student.headshot_photo)
    end

    it 'returns headshot if headshot_photo is not attached' do
      student.headshot.attach(io: StringIO.new('data'), filename: 'photo.jpg', content_type: 'image/jpeg')
      expect(student.attached_photo).to eq(student.headshot)
    end

    it 'returns nil if neither is attached' do
      expect(student.attached_photo).to be_nil
    end
  end
end
