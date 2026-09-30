# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffAvailability, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:staff_member) }
    it { is_expected.to belong_to(:session_block_definition).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:unavailable_date) }
    it { is_expected.to validate_presence_of(:staff_member_id) }

    describe "uniqueness validations" do
      let(:staff_member) { create(:staff_member) }
      let(:block) { create(:session_block_definition) }
      let(:date) { Date.current }

      it "prevents duplicate full-day unavailability on the same date" do
        create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: nil)
        duplicate = build(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: nil)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to include("Staff member is already marked unavailable for the full day on this date")
      end

      it "prevents duplicate block-specific unavailability on the same date and block" do
        create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block)
        duplicate = build(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to include("Staff member is already marked unavailable for this session block on this date")
      end

      it "allows different blocks on the same date" do
        block2 = create(:session_block_definition, name: "Block 2", start_time: "13:00", end_time: "15:00")
        create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block)
        different_block = build(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block2)

        expect(different_block).to be_valid
      end

      it "allows unavailability for different staff members on the same date and block" do
        staff2 = create(:staff_member)
        create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block)
        other_staff = build(:staff_availability, staff_member: staff2, unavailable_date: date, session_block_definition: block)

        expect(other_staff).to be_valid
      end
    end
  end

  describe "#full_day?" do
    let(:staff_member) { create(:staff_member) }
    let(:block) { create(:session_block_definition) }

    it "returns true when session_block_definition_id is nil" do
      record = build(:staff_availability, staff_member: staff_member, session_block_definition: nil)
      expect(record.full_day?).to be true
    end

    it "returns false when session_block_definition_id is present" do
      record = build(:staff_availability, staff_member: staff_member, session_block_definition: block)
      expect(record.full_day?).to be false
    end
  end

  describe "StaffMember#available_for_date? and unavailable_for_date?" do
    let(:staff_member) { create(:staff_member) }
    let(:block) { create(:session_block_definition) }
    let(:date) { Date.current }

    it "marks teacher unavailable when full-day unavailability exists" do
      expect(staff_member.available_for_date?(date)).to be true
      expect(staff_member.unavailable_for_date?(date)).to be false

      create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: nil)

      expect(staff_member.unavailable_for_date?(date)).to be true
      expect(staff_member.available_for_date?(date)).to be false
      expect(staff_member.available_for_date?(date, block.id)).to be false
    end

    it "marks teacher unavailable only for the specific block when block is specified" do
      block2 = create(:session_block_definition, name: "Block 2", start_time: "13:00", end_time: "15:00")
      create(:staff_availability, staff_member: staff_member, unavailable_date: date, session_block_definition: block)

      expect(staff_member.unavailable_for_date?(date, block.id)).to be true
      expect(staff_member.available_for_date?(date, block.id)).to be false

      expect(staff_member.unavailable_for_date?(date, block2.id)).to be false
      expect(staff_member.available_for_date?(date, block2.id)).to be true
    end
  end
end
