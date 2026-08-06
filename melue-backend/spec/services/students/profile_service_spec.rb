# frozen_string_literal: true

require "rails_helper"

RSpec.describe Students::ProfileService, type: :service do
  let(:admin)   { create(:staff_member, :admin) }
  let(:teacher) { create(:staff_member) }
  let(:student) { create(:student, :basic_therapy_young, :with_guardian, first_name: "Liya", last_name: "Bekele") }

  def call(staff:, student_id: student.id)
    described_class.call(student_id: student_id, current_user: staff.user)
  end

  describe "success" do
    it "returns a successful result for admin" do
      expect(call(staff: admin)).to be_success
    end

    it "includes the full name" do
      result = call(staff: admin)
      expect(result.data[:full_name]).to eq(student.full_name)
    end

    it "calculates the age correctly from date_of_birth" do
      result = call(staff: admin)
      expected_age = ((Date.current - student.date_of_birth) / 365.25).floor
      expect(result.data[:age]).to be_within(1).of(expected_age)
    end

    it "includes guardian_name and guardian_phone" do
      result = call(staff: admin)
      expect(result.data[:guardian_name]).to eq(student.guardian_name)
      expect(result.data[:guardian_phone]).to eq(student.guardian_phone)
    end

    it "includes program_type and therapy_group" do
      result = call(staff: admin)
      expect(result.data[:program_type]).to eq(student.program_type)
      expect(result.data[:therapy_group]).to eq(student.therapy_group)
    end

    it "returns headshot_url as nil when no headshot attached" do
      result = call(staff: admin)
      expect(result.data[:headshot_url]).to be_nil
    end

    it "returns current_goals_summary as an array" do
      result = call(staff: admin)
      expect(result.data[:current_goals_summary]).to be_an(Array)
    end
  end

  describe "goals summary" do
    let(:station)   { create(:therapy_station) }
    let(:iup)       { create(:iup, student: student, status: "active") }
    let(:goal1)     { create(:goal) }
    let(:goal2)     { create(:goal) }
    let(:goal3)     { create(:goal) }

    before do
      create(:student_goal, student: student, iup: iup, therapy_station: station, goal: goal1, status: "active")
      create(:student_goal, student: student, iup: iup, therapy_station: station, goal: goal2, status: "in_progress")
      # A third goal to verify only 2 are returned
      create(:student_goal, student: student, iup: iup, therapy_station: station, goal: goal3, status: "active")
    end

    it "includes at most 2 goals per station" do
      result = call(staff: admin)
      station_entry = result.data[:current_goals_summary].first
      expect(station_entry[:goals].count).to be <= 2
    end

    it "groups goals by station" do
      result = call(staff: admin)
      station_entry = result.data[:current_goals_summary].first
      expect(station_entry[:station][:id]).to eq(station.id)
    end
  end

  describe "RBAC — teacher access" do
    let(:station) { create(:therapy_station) }
    let(:room)    { create(:therapy_room, therapy_station: station) }
    let(:block)   { create(:session_block_definition) }

    context "when teacher is assigned to the student" do
      before do
        create(:teacher_student_assignment,
          teacher: teacher, student: student,
          therapy_station: station, therapy_room: room,
          session_block_definition: block, scheduled_date: Date.current)
      end

      it "returns the student profile successfully" do
        expect(call(staff: teacher)).to be_success
      end
    end

    context "when teacher is NOT assigned to the student" do
      it "returns a failure result" do
        result = call(staff: teacher)
        expect(result).not_to be_success
        expect(result.error).to match(/not found/i)
      end
    end
  end

  describe "failures" do
    it "fails when student does not exist" do
      result = call(staff: admin, student_id: SecureRandom.uuid)
      expect(result).not_to be_success
      expect(result.error).to match(/not found/i)
    end

    it "fails when current_user has no staff profile" do
      orphan_user = create(:user)
      result = described_class.call(student_id: student.id, current_user: orphan_user)
      expect(result).not_to be_success
      expect(result.error).to match(/staff profile required/i)
    end
  end
end
