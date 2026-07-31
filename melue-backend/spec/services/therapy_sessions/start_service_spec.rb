# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapySessions::StartService, type: :service do
  subject(:result) { described_class.call(assignment: assignment, staff_member: teacher) }

  let(:teacher)  { create(:staff_member) }
  let(:station)  { create(:therapy_station) }
  let(:room)     { create(:therapy_room, therapy_station: station) }
  let(:block)    { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }

  let!(:assignment) do
    create(:teacher_student_assignment,
           teacher: teacher,
           student: student1,
           session_block_definition: block,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: Date.current)
  end

  let!(:assignment2) do
    create(:teacher_student_assignment,
           teacher: teacher,
           student: student2,
           session_block_definition: block,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: Date.current)
  end

  describe "success" do
    it "returns a successful result" do
      expect(result).to be_success
    end

    it "creates a TherapySession" do
      expect { result }.to change(TherapySession, :count).by(1)
    end

    it "creates exactly two SessionParticipants" do
      expect { result }.to change(SessionParticipant, :count).by(2)
    end

    it "assigns active and secondary card positions" do
      result
      session = TherapySession.last
      expect(session.session_participants.map(&:card_position)).to match_array(%w[active secondary])
    end

    it "sets session status to in_progress" do
      result
      expect(TherapySession.last.status).to eq("in_progress")
    end
  end

  describe "idempotency" do
    it "returns the existing session if already started" do
      first_result  = described_class.call(assignment: assignment, staff_member: teacher)
      second_result = described_class.call(assignment: assignment, staff_member: teacher)

      expect(second_result).to be_success
      expect(second_result.data.id).to eq(first_result.data.id)
      expect(TherapySession.count).to eq(1)
    end
  end

  describe "failures" do
    it "fails when the caller is not the assigned teacher" do
      other_teacher = create(:staff_member)
      result = described_class.call(assignment: assignment, staff_member: other_teacher)
      expect(result).not_to be_success
      expect(result.error).to match(/not the assigned teacher/i)
    end

    it "fails when assignment is not for today" do
      assignment.update_column(:scheduled_date, Date.current - 1.day)
      expect(result).not_to be_success
      expect(result.error).to match(/not for today/i)
    end

    it "fails when assignment is not scheduled" do
      assignment.update_column(:status, "cancelled")
      expect(result).not_to be_success
      expect(result.error).to match(/not scheduled/i)
    end

    it "fails when there is only one assignment for the block" do
      assignment2.destroy
      expect(result).not_to be_success
      expect(result.error).to match(/exactly 2/i)
    end
  end
end
