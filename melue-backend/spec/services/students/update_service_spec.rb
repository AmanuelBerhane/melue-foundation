# frozen_string_literal: true

require "rails_helper"

RSpec.describe Students::UpdateService, type: :service do
  let(:coordinator)     { create(:staff_member, :therapy_coordinator) }
  let(:program_director) { create(:staff_member, :program_director) }
  let(:teacher)         { create(:staff_member) }
  let(:admin)           { create(:staff_member, :admin) }

  let(:student) do
    create(:student,
      first_name: "Yonas",
      last_name: "Girma",
      date_of_birth: 7.years.ago.to_date,
      therapy_group: "basic",
      program_type: "regular")
  end

  def call(staff:, params: {})
    described_class.call(student_id: student.id, params: params, current_user: staff.user)
  end

  describe "success" do
    it "allows a therapy coordinator to update a student" do
      result = call(staff: coordinator, params: { first_name: "Dawit" })
      expect(result).to be_success
    end

    it "allows a program director to update a student" do
      result = call(staff: program_director, params: { first_name: "Liya" })
      expect(result).to be_success
    end

    it "persists the updated field" do
      call(staff: coordinator, params: { last_name: "Bekele" })
      expect(student.reload.last_name).to eq("Bekele")
    end

    it "returns the updated student in data" do
      result = call(staff: coordinator, params: { first_name: "Updated" })
      expect(result.data[:student].first_name).to eq("Updated")
    end

    it "returns no warning when age matches therapy group" do
      params = { date_of_birth: 8.years.ago.to_date, therapy_group: "basic" }
      result = call(staff: coordinator, params: params)
      expect(result.data[:warning]).to be_nil
    end
  end

  describe "soft age-mismatch warning" do
    it "succeeds but includes a warning when age mismatches therapy group" do
      # Updating to FLS but keeping age 7 (Basic range)
      params = { therapy_group: "functional_living" }
      result = call(staff: coordinator, params: params)
      expect(result).to be_success
      expect(result.data[:warning]).to match(/does not match.*functional living skills/i)
    end

    it "allows the update to go through despite the mismatch" do
      params = { therapy_group: "functional_living" }
      call(staff: coordinator, params: params)
      expect(student.reload.therapy_group).to eq("functional_living")
    end

    it "returns a warning when student is too old for basic therapy" do
      params = { date_of_birth: 14.years.ago.to_date, therapy_group: "basic" }
      result = call(staff: coordinator, params: params)
      expect(result).to be_success
      expect(result.data[:warning]).to match(/does not match.*basic therapy/i)
    end
  end

  describe "RBAC denial" do
    it "denies a teacher from editing a student" do
      result = call(staff: teacher, params: { first_name: "ShouldFail" })
      expect(result).not_to be_success
      expect(result.error).to match(/permission/i)
    end

    it "does not modify the record when denied" do
      call(staff: teacher, params: { first_name: "ShouldFail" })
      expect(student.reload.first_name).to eq("Yonas")
    end

    it "denies an admin from editing (admin can view but not edit)" do
      result = call(staff: admin, params: { first_name: "ShouldFail" })
      expect(result).not_to be_success
      expect(result.error).to match(/permission/i)
    end
  end

  describe "failures" do
    it "fails when student does not exist" do
      result = described_class.call(
        student_id: SecureRandom.uuid,
        params: { first_name: "Ghost" },
        current_user: coordinator.user
      )
      expect(result).not_to be_success
      expect(result.error).to match(/not found/i)
    end

    it "fails when current_user has no staff profile" do
      orphan_user = create(:user)
      result = described_class.call(
        student_id: student.id,
        params: { first_name: "Fail" },
        current_user: orphan_user
      )
      expect(result).not_to be_success
      expect(result.error).to match(/staff profile required/i)
    end
  end
end
