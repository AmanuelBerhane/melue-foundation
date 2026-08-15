require 'rails_helper'

RSpec.describe 'RSpec Setup' do
  it 'works' do
    expect(true).to be true
  end

  it 'can access the Student model' do
    expect(defined?(Student)).to eq('constant')
  end

  it 'can create a student' do
    student = Student.new(
      first_name: 'Test',
      last_name: 'Student',
      date_of_birth: '2015-01-01',
      guardian_name: 'Guardian Name',
      guardian_phone: '555-1234',
      guardian_email: 'guardian@example.com',
      program_type: 'regular',
      therapy_group: 'basic',
      status: 'draft'  # Add this line
    )
    expect(student.save).to be true
    expect(student.persisted?).to be true
    expect(student.id).not_to be_nil
    expect(student.guardian_name).to eq('Guardian Name')
  end
end
