# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgramDirector::DashboardService, type: :service do
  describe "#call" do
    context "when data exists" do
      before do
        # 3 students in assessment
        create_list(:student, 3, status: "in_assessment")
        # 2 students with assessment complete / ready for iup
        create(:student, status: "assessment_complete")
        create(:student, status: "ready_for_iup")
        # 1 active student (should not be counted in assessment counts)
        create(:student, status: "active")

        # 4 active IUPs
        active_iups = create_list(:iup, 4, status: "active")
        # 2 draft IUPs (should not be counted)
        create_list(:iup, 2, status: "draft")

        # 5 goals assigned this month (3 current, 2 older)
        iup = active_iups.first
        student = iup.student
        goal = create(:goal)
        station1 = create(:therapy_station)
        station2 = create(:therapy_station)
        station3 = create(:therapy_station)

        create(:student_goal, student: student, iup: iup, goal: goal, therapy_station: station1, created_at: Time.current)
        create(:student_goal, student: student, iup: iup, goal: goal, therapy_station: station2, created_at: Time.current)
        create(:student_goal, student: student, iup: iup, goal: goal, therapy_station: station3, created_at: Time.current)

        create(:student_goal, student: student, iup: iup, goal: goal, therapy_station: station1, created_at: 2.months.ago)
        create(:student_goal, student: student, iup: iup, goal: goal, therapy_station: station2, created_at: 2.months.ago)
      end

      it "returns correct counts for the dashboard metrics" do
        result = described_class.call

        expect(result).to be_success
        expect(result.data).to eq({
          students_in_assessment: 3,
          assessment_complete: 2,
          active_iup_plans: 4,
          goals_assigned_this_month: 3
        })
      end
    end

    context "when database is empty" do
      it "returns zero for all metrics" do
        result = described_class.call

        expect(result).to be_success
        expect(result.data).to eq({
          students_in_assessment: 0,
          assessment_complete: 0,
          active_iup_plans: 0,
          goals_assigned_this_month: 0
        })
      end
    end
  end
end
