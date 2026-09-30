# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapyCoordinator::MarkTeacherUnavailableService do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:teacher) { create(:staff_member, role: "teacher") }
  let(:block) { create(:session_block_definition) }
  let(:date) { Date.current }

  describe "#call" do
    context "with valid full-day unavailability" do
      it "creates a StaffAvailability record and returns success" do
        service = described_class.new({
          teacher_id: teacher.id,
          unavailable_date: date.to_s,
          reason: "Attending annual workshop"
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        availability = result.data[:availability]
        expect(availability).to be_persisted
        expect(availability.staff_member_id).to eq(teacher.id)
        expect(availability.unavailable_date).to eq(date)
        expect(availability.reason).to eq("Attending annual workshop")
        expect(availability.full_day?).to be true
      end
    end

    context "with block-specific unavailability" do
      it "creates a block-specific StaffAvailability record" do
        service = described_class.new({
          teacher_id: teacher.id,
          session_block_definition_id: block.id,
          unavailable_date: date.to_s,
          reason: "Doctor appointment morning block"
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        availability = result.data[:availability]
        expect(availability.session_block_definition_id).to eq(block.id)
        expect(availability.full_day?).to be false
      end
    end

    context "when teacher has existing scheduled assignments" do
      let(:student) { create(:student) }
      let(:station) { create(:therapy_station) }
      let(:room) { create(:therapy_room, therapy_station: station) }

      let!(:assignment) do
        create(:teacher_student_assignment,
               teacher: teacher,
               student: student,
               session_block_definition: block,
               therapy_station: station,
               therapy_room: room,
               scheduled_date: date,
               status: "scheduled")
      end

      it "identifies and returns impacted assignments" do
        service = described_class.new({
          teacher_id: teacher.id,
          session_block_definition_id: block.id,
          unavailable_date: date.to_s,
          reason: "Family emergency"
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        expect(result.data[:impacted_assignments_count]).to eq(1)
        expect(result.data[:impacted_assignments].first.id).to eq(assignment.id)
      end
    end

    context "with invalid data" do
      it "returns failure when teacher is not found" do
        service = described_class.new({
          teacher_id: SecureRandom.uuid,
          unavailable_date: date.to_s
        }, coordinator_user)

        result = service.call
        expect(result).not_to be_success
        expect(result.error).to eq("Teacher not found")
      end

      it "returns failure when date format is invalid" do
        service = described_class.new({
          teacher_id: teacher.id,
          unavailable_date: "invalid-date"
        }, coordinator_user)

        result = service.call
        expect(result).not_to be_success
        expect(result.error).to include("Invalid unavailable_date format")
      end

      it "returns failure when session block definition does not exist" do
        service = described_class.new({
          teacher_id: teacher.id,
          unavailable_date: date.to_s,
          session_block_definition_id: SecureRandom.uuid
        }, coordinator_user)

        result = service.call
        expect(result).not_to be_success
        expect(result.error).to eq("Session block definition not found")
      end

      it "prevents duplicate unavailability records" do
        create(:staff_availability, staff_member: teacher, unavailable_date: date, session_block_definition: nil)

        service = described_class.new({
          teacher_id: teacher.id,
          unavailable_date: date.to_s
        }, coordinator_user)

        result = service.call
        expect(result).not_to be_success
        expect(result.error).to include("already marked unavailable")
      end
    end
  end
end
