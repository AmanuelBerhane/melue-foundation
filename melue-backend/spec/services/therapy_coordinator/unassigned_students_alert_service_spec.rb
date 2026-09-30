# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapyCoordinator::UnassignedStudentsAlertService do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:teacher) { create(:staff_member, role: "teacher") }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }

  let!(:morning_block) do
    create(:session_block_definition,
           name: "Morning Round 1",
           round: "morning",
           start_time: Time.zone.parse("09:00:00"),
           end_time: Time.zone.parse("11:30:00"),
           is_active: true)
  end

  let!(:afternoon_block) do
    create(:session_block_definition,
           name: "Afternoon Round 1",
           round: "afternoon",
           start_time: Time.zone.parse("13:00:00"),
           end_time: Time.zone.parse("15:30:00"),
           is_active: true)
  end

  let!(:assigned_student) { create(:student, first_name: "Assigned", status: "active_therapy") }
  let!(:unassigned_student) { create(:student, first_name: "Unassigned", status: "active_therapy") }
  let!(:discharged_student) { create(:student, first_name: "Discharged", status: "discharged") }

  let(:date) { Date.current }

  describe "#call" do
    before do
      # Assigned student is scheduled for morning block
      create(:teacher_student_assignment,
             teacher: teacher,
             student: assigned_student,
             session_block_definition: morning_block,
             therapy_station: station,
             therapy_room: room,
             scheduled_date: date,
             status: "scheduled")
    end

    context "when evaluated during morning block (current block)" do
      let(:eval_time) { Time.zone.parse("#{date} 10:00:00") }

      it "flags unassigned student with high severity for current block and warning for upcoming block" do
        service = described_class.new({
          date: date.to_s,
          current_time: eval_time.to_s
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        data = result.data

        expect(data[:current_block][:id]).to eq(morning_block.id)
        expect(data[:upcoming_block][:id]).to eq(afternoon_block.id)

        alerts = data[:alerts]
        unassigned_ids = alerts.map { |a| a[:student_id] }

        # Unassigned student should be flagged
        expect(unassigned_ids).to include(unassigned_student.id)
        # Discharged student should never be flagged
        expect(unassigned_ids).not_to include(discharged_student.id)

        # Check morning block alert for unassigned student
        morning_alert = alerts.find { |a| a[:student_id] == unassigned_student.id && a[:session_block_definition_id] == morning_block.id }
        expect(morning_alert).to be_present
        expect(morning_alert[:severity]).to eq("high")
        expect(morning_alert[:is_current_block]).to be true

        # Assigned student is NOT flagged for morning block
        assigned_morning = alerts.find { |a| a[:student_id] == assigned_student.id && a[:session_block_definition_id] == morning_block.id }
        expect(assigned_morning).to be_nil
      end
    end

    context "when filtering by a specific block" do
      it "returns unassigned alerts only for that specific block" do
        service = described_class.new({
          date: date.to_s,
          session_block_definition_id: morning_block.id
        }, coordinator_user)

        result = service.call

        expect(result).to be_success
        data = result.data
        expect(data[:alerts].all? { |a| a[:session_block_definition_id] == morning_block.id }).to be true
        expect(data[:alerts].map { |a| a[:student_id] }).to eq([ unassigned_student.id ])
      end
    end
  end
end
