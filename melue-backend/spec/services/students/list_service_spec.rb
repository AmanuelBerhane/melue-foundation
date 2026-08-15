# frozen_string_literal: true

require "rails_helper"

RSpec.describe Students::ListService, type: :service do
  let(:admin)       { create(:staff_member, :admin) }
  let(:coordinator) { create(:staff_member, :therapy_coordinator) }
  let(:teacher)     { create(:staff_member) }

  let(:student1) { create(:student, :basic_therapy_young, first_name: "Abebe", last_name: "Girma",  program_type: "regular") }
  let(:student2) { create(:student, :functional_living,   first_name: "Meron", last_name: "Haile",  program_type: "pulled_out") }
  let(:student3) { create(:student, :basic_therapy_young, first_name: "Yonas", last_name: "Tadesse", program_type: "regular") }

  def call(staff:, params: {})
    described_class.call(current_user: staff.user, params: params)
  end

  describe "success" do
    before { student1; student2; student3 }

    it "returns a successful result" do
      expect(call(staff: admin)).to be_success
    end

    it "returns all students for an admin" do
      result = call(staff: admin)
      expect(result.data[:students].count).to eq(3)
    end

    it "returns all students for a coordinator" do
      result = call(staff: coordinator)
      expect(result.data[:students].count).to eq(3)
    end

    it "returns pagination meta" do
      result = call(staff: admin)
      meta = result.data[:meta]
      expect(meta).to include(
        current_page: 1,
        total_count: 3,
        total_pages: 1
      )
    end
  end

  describe "filtering" do
    before { student1; student2; student3 }

    it "filters by name query (first name)" do
      result = call(staff: admin, params: { q: "Abebe" })
      expect(result.data[:students].map(&:first_name)).to contain_exactly("Abebe")
    end

    it "filters by name query (last name)" do
      result = call(staff: admin, params: { q: "Haile" })
      expect(result.data[:students].map(&:last_name)).to contain_exactly("Haile")
    end

    it "filters by program_type" do
      result = call(staff: admin, params: { program_type: "pulled_out" })
      expect(result.data[:students].map(&:first_name)).to contain_exactly("Meron")
    end

    it "filters by therapy_group" do
      result = call(staff: admin, params: { therapy_group: "functional_living" })
      expect(result.data[:students].map(&:first_name)).to contain_exactly("Meron")
    end
  end

  describe "pagination" do
    before { 5.times { create(:student) } }

    it "paginates results" do
      result = call(staff: admin, params: { per_page: 2, page: 1 })
      expect(result.data[:students].count).to eq(2)
    end

    it "returns correct total_pages" do
      result = call(staff: admin, params: { per_page: 2 })
      expect(result.data[:meta][:total_pages]).to eq(3)
    end

    it "returns the second page" do
      result_p1 = call(staff: admin, params: { per_page: 2, page: 1 })
      result_p2 = call(staff: admin, params: { per_page: 2, page: 2 })
      ids_p1 = result_p1.data[:students].map(&:id)
      ids_p2 = result_p2.data[:students].map(&:id)
      expect(ids_p1 & ids_p2).to be_empty
    end
  end

  describe "RBAC — teacher sees only assigned students" do
    let(:station) { create(:therapy_station) }
    let(:room)    { create(:therapy_room, therapy_station: station) }
    let(:block)   { create(:session_block_definition) }

    before do
      student1; student2; student3
      create(:teacher_student_assignment,
        teacher: teacher, student: student1,
        therapy_station: station, therapy_room: room,
        session_block_definition: block, scheduled_date: Date.current)
    end

    it "returns only assigned students for a teacher" do
      result = call(staff: teacher)
      expect(result.data[:students].map(&:id)).to contain_exactly(student1.id)
    end

    it "does not return unassigned students for a teacher" do
      result = call(staff: teacher)
      ids = result.data[:students].map(&:id)
      expect(ids).not_to include(student2.id, student3.id)
    end
  end

  describe "failures" do
    it "fails when current_user has no staff profile" do
      orphan_user = create(:user)
      result = described_class.call(current_user: orphan_user, params: {})
      expect(result).not_to be_success
      expect(result.error).to match(/staff profile required/i)
    end
  end
end
