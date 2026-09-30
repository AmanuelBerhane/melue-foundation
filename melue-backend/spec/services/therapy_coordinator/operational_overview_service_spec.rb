# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapyCoordinator::OperationalOverviewService do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:teacher1) { create(:staff_member, full_name: "Teacher One", role: "teacher") }
  let(:teacher2) { create(:staff_member, full_name: "Teacher Two", role: "teacher") }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }
  let(:student) { create(:student, status: "active_therapy") }

  let!(:block) do
    create(:session_block_definition,
           name: "Morning Block",
           round: "morning",
           start_time: Time.zone.parse("09:00:00"),
           end_time: Time.zone.parse("11:30:00"),
           is_active: true)
  end

  let(:date) { Date.current }

  before do
    # Teacher 1 has 1 assignment
    create(:teacher_student_assignment,
           teacher: teacher1,
           student: student,
           session_block_definition: block,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: date,
           status: "scheduled")

    # Teacher 2 is marked unavailable
    create(:staff_availability,
           staff_member: teacher2,
           unavailable_date: date,
           reason: "Sick leave")
  end

  describe "#call" do
    it "assembles the complete operational management screen data" do
      service = described_class.new({ date: date.to_s }, coordinator_user)
      result = service.call

      expect(result).to be_success
      data = result.data

      # Summary
      expect(data[:summary][:total_teachers]).to eq(2)
      expect(data[:summary][:available_teachers]).to eq(1)
      expect(data[:summary][:unavailable_teachers]).to eq(1)
      expect(data[:summary][:total_assignments]).to eq(1)

      # Teachers
      t1_card = data[:teachers].find { |t| t[:teacher_id] == teacher1.id }
      expect(t1_card[:is_available]).to be true
      expect(t1_card[:capacity][:current]).to eq(1)

      t2_card = data[:teachers].find { |t| t[:teacher_id] == teacher2.id }
      expect(t2_card[:is_available]).to be false
      expect(t2_card[:unavailabilities].first[:reason]).to eq("Sick leave")
    end
  end
end
