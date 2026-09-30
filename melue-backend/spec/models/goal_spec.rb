# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goal, type: :model do
  let(:domain) { create(:goal_domain, name: "Communication") }

  describe "validations" do
    it "is valid with valid attributes" do
      goal = build(:goal, goal_domain: domain, name: "Vocal Requesting", goal_type: "standard")
      expect(goal).to be_valid
    end

    it "requires a name" do
      goal = build(:goal, name: nil)
      expect(goal).not_to be_valid
      expect(goal.errors[:name]).to include("can't be blank")
    end

    it "requires a goal_domain" do
      goal = build(:goal, goal_domain: nil)
      expect(goal).not_to be_valid
      expect(goal.errors[:goal_domain]).to be_present
    end

    it "requires a goal_type" do
      goal = build(:goal, goal_type: nil)
      expect(goal).not_to be_valid
      expect(goal.errors[:goal_type]).to include("can't be blank")
    end

    it "validates uniqueness of step numbers for task analysis goals" do
      goal = create(:goal, :task_analysis, goal_domain: domain)
      create(:task_analysis_step_template, goal: goal, step_number: 1, name: "Step 1")

      duplicate_step = build(:task_analysis_step_template, goal: goal, step_number: 1, name: "Duplicate Step 1")
      expect(duplicate_step).not_to be_valid
      expect(duplicate_step.errors[:step_number]).to include("has already been taken")
    end
  end

  describe "scopes" do
    let!(:active_standard) { create(:goal, goal_domain: domain, goal_type: "standard", is_active: true, name: "Alpha") }
    let!(:inactive_ta) { create(:goal, :task_analysis, goal_domain: domain, is_active: false, name: "Beta") }

    it "filters active goals" do
      expect(described_class.active).to include(active_standard)
      expect(described_class.active).not_to include(inactive_ta)
    end

    it "filters inactive goals" do
      expect(described_class.inactive).to include(inactive_ta)
      expect(described_class.inactive).not_to include(active_standard)
    end

    it "filters standard goals" do
      expect(described_class.standard).to include(active_standard)
      expect(described_class.standard).not_to include(inactive_ta)
    end

    it "filters task analysis goals" do
      expect(described_class.task_analysis).to include(inactive_ta)
      expect(described_class.task_analysis).not_to include(active_standard)
    end

    it "searches by query matching name or description" do
      active_standard.update!(description: "Teaching conversational speech")
      expect(described_class.search_text("conversational")).to include(active_standard)
      expect(described_class.search_text("beta")).to include(inactive_ta)
    end
  end

  describe "usage_count and active_student_assignments (FR-078)" do
    let(:goal) { create(:goal, goal_domain: domain) }
    let(:station) { create(:therapy_station) }
    let(:active_student1) { create(:student, status: "active") }
    let(:active_student2) { create(:student, status: "active_therapy") }
    let(:withdrawn_student) { create(:student, status: "withdrawn") }

    it "returns 0 when no students are assigned" do
      expect(goal.usage_count).to eq(0)
      expect(goal.assigned_to_active_students?).to be false
    end

    it "counts distinct active students assigned to the goal" do
      iup1 = create(:iup, student: active_student1, status: "active")
      iup2 = create(:iup, student: active_student2, status: "active")

      create(:student_goal, goal: goal, student: active_student1, iup: iup1, therapy_station: station, status: "active")
      create(:student_goal, goal: goal, student: active_student2, iup: iup2, therapy_station: station, status: "in_progress")

      expect(goal.usage_count).to eq(2)
      expect(goal.assigned_to_active_students?).to be true
    end

    it "excludes withdrawn, discharged, or archived students" do
      iup_withdrawn = create(:iup, student: withdrawn_student, status: "active")
      create(:student_goal, goal: goal, student: withdrawn_student, iup: iup_withdrawn, therapy_station: station, status: "active")

      expect(goal.usage_count).to eq(0)
      expect(goal.assigned_to_active_students?).to be false
    end

    it "excludes archived student goals" do
      iup = create(:iup, student: active_student1, status: "active")
      create(:student_goal, goal: goal, student: active_student1, iup: iup, therapy_station: station, status: "archived")

      expect(goal.usage_count).to eq(0)
      expect(goal.assigned_to_active_students?).to be false
    end

    it "uses custom_usage_count if set" do
      goal.custom_usage_count = 5
      expect(goal.usage_count).to eq(5)
    end
  end

  describe "deactivate! and activate! (FR-076)" do
    let(:goal) { create(:goal, is_active: true) }

    it "deactivates an active goal" do
      goal.deactivate!
      expect(goal.reload.is_active).to be false
    end

    it "activates a deactivated goal" do
      goal.update!(is_active: false)
      goal.activate!
      expect(goal.reload.is_active).to be true
    end
  end

  describe "deletion protection (FR-077)" do
    let(:goal) { create(:goal, goal_domain: domain) }
    let(:station) { create(:therapy_station) }
    let(:active_student) { create(:student, status: "active") }

    it "prevents deletion when assigned to active students" do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal, student: active_student, iup: iup, therapy_station: station, status: "active")

      expect(goal.destroy).to be false
      expect(goal.errors[:base]).to include("Cannot delete goal currently assigned to active students")
      expect { goal.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(described_class.exists?(goal.id)).to be true
    end

    it "prevents discard when assigned to active students" do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal, student: active_student, iup: iup, therapy_station: station, status: "active")

      expect(goal.discard).to be false
      expect(goal.errors[:base]).to include("Cannot delete goal currently assigned to active students")
      expect(goal.reload.discarded?).to be false
    end

    it "allows deletion when not assigned to any students" do
      expect { goal.destroy }.not_to raise_error
      expect(described_class.exists?(goal.id)).to be false
    end
  end
end
