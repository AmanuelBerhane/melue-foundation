# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessmentCycle, type: :model do
  let(:student) { create(:student, status: "in_assessment") }
  let(:cycle) { create(:assessment_cycle, student: student, status: "in_progress") }

  describe "#check_and_mark_complete!" do
    let!(:skills) { create(:skills_assessment, assessment_cycle: cycle, status: "draft") }
    let!(:behavior) { create(:behavior_assessment, assessment_cycle: cycle, status: "draft") }
    let!(:preference) { create(:preference_assessment, assessment_cycle: cycle, status: "draft") }

    it "does not mark complete if any assessment is not submitted" do
      skills.update!(status: "submitted")
      behavior.update!(status: "submitted")

      cycle.check_and_mark_complete!

      expect(cycle.reload.status).not_to eq("complete")
      expect(student.reload.status).to eq("in_assessment")
    end

    it "updates student.status to assessment_complete upon final submission (FR-050)" do
      skills.update!(status: "submitted")
      behavior.update!(status: "submitted")
      preference.update!(status: "submitted")

      cycle.reload.check_and_mark_complete!

      expect(cycle.reload.status).to eq("complete")
      expect(cycle.completed_on).to eq(Date.current)
      expect(student.reload.status).to eq("assessment_complete")
    end
  end
end
