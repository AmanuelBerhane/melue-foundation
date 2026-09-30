# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeletionCheckService, type: :service do
  let(:domain) { create(:goal_domain) }
  let(:station) { create(:therapy_station) }

  describe "when checking a Goal (FR-077)" do
    let(:goal) { create(:goal, goal_domain: domain) }
    let(:active_student) { create(:student, status: "active") }
    let(:withdrawn_student) { create(:student, status: "withdrawn") }

    it "fails if goal is assigned to active students" do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal, student: active_student, iup: iup, therapy_station: station, status: "active")

      result = described_class.call(goal)

      expect(result.success?).to be false
      expect(result.error).to eq("Cannot delete goal currently assigned to active students")
    end

    it "succeeds if goal has no student assignments" do
      result = described_class.call(goal)

      expect(result.success?).to be true
    end

    it "succeeds if goal is only assigned to withdrawn/discharged/archived students" do
      iup = create(:iup, student: withdrawn_student, status: "active")
      create(:student_goal, goal: goal, student: withdrawn_student, iup: iup, therapy_station: station, status: "active")

      result = described_class.call(goal)

      expect(result.success?).to be true
    end

    it "succeeds if student goals are all archived" do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal, student: active_student, iup: iup, therapy_station: station, status: "archived")

      result = described_class.call(goal)

      expect(result.success?).to be true
    end
  end
end
