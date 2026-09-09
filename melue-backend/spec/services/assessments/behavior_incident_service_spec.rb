# spec/services/assessments/behavior_incident_service_spec.rb
require 'rails_helper'

RSpec.describe Assessments::BehaviorIncidentService, type: :service do
  let(:student) { create(:student) }
  let(:staff_member) { create(:staff_member, role: 'teacher') }
  let(:current_user) { create(:user, staff_member: staff_member) }

  describe '#create' do
    it 'creates a behavior incident' do
      params = {
        behavior_name: 'Elopement',
        frequency: 'frequently',
        intensity: 'moderate',
        category: 'safety_concerns',
        antecedent: 'Transition to new activity',
        consequence: 'Redirected back',
        location: 'Classroom',
        occurred_at: Time.current
      }

      service = described_class.new(student, params, current_user)
      result = service.create

      expect(result.success?).to be true
      expect(result.data.behavior_name).to eq('Elopement')
      expect(result.data.student_id).to eq(student.id)
      expect(result.data.staff_member_id).to eq(staff_member.id)
    end

    it 'auto-populates behavior definition' do
      params = {
        behavior_name: 'Screaming',
        frequency: 'frequently',
        intensity: 'moderate',
        category: 'making_noises',
        antecedent: 'During circle time',
        consequence: 'Removed from activity',
        location: 'Classroom'
      }

      service = described_class.new(student, params, current_user)
      result = service.create

      expect(result.success?).to be true
      expect(result.data.behavior_definition).to be_present
    end

    it 'returns failure if required fields missing' do
      params = { behavior_name: 'Elopement' }

      service = described_class.new(student, params, current_user)
      result = service.create

      expect(result.success?).to be false
      expect(result.error).to include("Frequency can't be blank")
    end
  end

  describe '#update' do
    let(:incident) do
      create(:behavior_incident,
        student: student,
        staff_member: staff_member,
        behavior_name: 'Original Behavior'
      )
    end

    it 'updates a behavior incident' do
      service = described_class.new(student, { behavior_name: 'Updated Behavior' }, current_user, incident)
      result = service.update

      expect(result.success?).to be true
      expect(result.data.behavior_name).to eq('Updated Behavior')
    end

    it 'returns failure if user is not authorized' do
      other_teacher = create(:staff_member, role: 'teacher')
      other_user = create(:user, staff_member: other_teacher)

      service = described_class.new(student, { behavior_name: 'Updated' }, other_user, incident)
      result = service.update

      expect(result.success?).to be false
      expect(result.error).to include("don't have permission")
    end
  end
end
