# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapyCoordinator::ReassignStudentsService do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:source_teacher) { create(:staff_member, full_name: "Source Teacher", role: "teacher") }
  let(:target_teacher) { create(:staff_member, full_name: "Target Teacher", role: "teacher") }
  let(:block) { create(:session_block_definition) }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:date) { Date.current }

  let!(:assignment1) do
    create(:teacher_student_assignment,
           teacher: source_teacher,
           student: student1,
           session_block_definition: block,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: date,
           status: "scheduled")
  end

  describe "#call" do
    context "reassigning a single assignment" do
      it "reassigns student to target teacher successfully" do
        service = described_class.new({
          assignment_id: assignment1.id,
          new_teacher_id: target_teacher.id
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        expect(result.data[:reassigned_count]).to eq(1)
        expect(assignment1.reload.teacher_id).to eq(target_teacher.id)
      end
    end

    context "reassigning batch of assignments" do
      let!(:assignment2) do
        create(:teacher_student_assignment,
               teacher: source_teacher,
               student: student2,
               session_block_definition: block,
               therapy_station: station,
               therapy_room: room,
               scheduled_date: date,
               status: "scheduled")
      end

      it "reassigns multiple assignments to target teacher" do
        service = described_class.new({
          assignment_ids: [ assignment1.id, assignment2.id ],
          new_teacher_id: target_teacher.id
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        expect(result.data[:reassigned_count]).to eq(2)
        expect(assignment1.reload.teacher_id).to eq(target_teacher.id)
        expect(assignment2.reload.teacher_id).to eq(target_teacher.id)
      end
    end

    context "when target teacher is marked unavailable" do
      before do
        create(:staff_availability,
               staff_member: target_teacher,
               unavailable_date: date,
               session_block_definition: block,
               reason: "Sick leave")
      end

      it "fails reassignment and does not alter assignment" do
        service = described_class.new({
          assignment_id: assignment1.id,
          new_teacher_id: target_teacher.id
        }, coordinator_user)

        result = service.call

        expect(result).not_to be_success
        expect(result.error).to include("marked as unavailable")
        expect(assignment1.reload.teacher_id).to eq(source_teacher.id)
      end
    end

    context "when target teacher capacity would be exceeded" do
      before do
        # Fill target teacher's capacity to 4 (default max capacity)
        4.times do
          s = create(:student)
          create(:teacher_student_assignment,
                 teacher: target_teacher,
                 student: s,
                 session_block_definition: block,
                 therapy_station: station,
                 therapy_room: room,
                 scheduled_date: date,
                 status: "scheduled")
        end
      end

      it "rejects reassignment due to capacity limit" do
        service = described_class.new({
          assignment_id: assignment1.id,
          new_teacher_id: target_teacher.id
        }, coordinator_user)

        result = service.call

        expect(result).not_to be_success
        expect(result.error).to include("exceeds capacity")
        expect(assignment1.reload.teacher_id).to eq(source_teacher.id)
      end
    end

    context "when assignment is completed or cancelled" do
      it "rejects reassignment of completed assignment" do
        assignment1.update!(status: "completed")

        service = described_class.new({
          assignment_id: assignment1.id,
          new_teacher_id: target_teacher.id
        }, coordinator_user)

        result = service.call

        expect(result).not_to be_success
        expect(result.error).to include("Only scheduled assignments can be reassigned")
      end
    end
  end
end
