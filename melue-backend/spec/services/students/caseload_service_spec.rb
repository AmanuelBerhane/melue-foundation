# spec/services/students/caseload_service_spec.rb
require 'rails_helper'

RSpec.describe Students::CaseloadService, type: :service do
  let(:program_director) { create(:staff_member, role: 'program_director') }

  describe '#call' do
    it 'returns students with active IUPs' do
      student = create(:student)
      create(:iup, student: student, status: 'active')

      service = described_class.new(program_director)
      result = service.call

      expect(result.success?).to be true
      expect(result.data).to include(student)
    end

    it 'filters by search term' do
      student1 = create(:student, first_name: 'John')
      student2 = create(:student, first_name: 'Jane')
      create(:iup, student: student1, status: 'active')
      create(:iup, student: student2, status: 'active')

      service = described_class.new(program_director, { search: 'John' })
      result = service.call

      expect(result.success?).to be true
      expect(result.data).to include(student1)
      expect(result.data).not_to include(student2)
    end

    it 'filters by program type' do
      student1 = create(:student, program_type: 'regular')
      student2 = create(:student, program_type: 'pulled_out')
      create(:iup, student: student1, status: 'active')
      create(:iup, student: student2, status: 'active')

      service = described_class.new(program_director, { program_type: 'regular' })
      result = service.call

      expect(result.success?).to be true
      expect(result.data).to include(student1)
      expect(result.data).not_to include(student2)
    end

    it 'returns failure if user is not a program director' do
      teacher = create(:staff_member, role: 'teacher')
      service = described_class.new(teacher)
      result = service.call

      expect(result.success?).to be false
      expect(result.error).to include('Program Director not found')
    end
  end
end
