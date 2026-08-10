# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreferenceAssessment, type: :model do
  let(:cycle) { create(:assessment_cycle) }

  it "starts as a draft" do
    expect(create(:preference_assessment, assessment_cycle: cycle)).to be_status_draft
  end

  it "allows only one assessment per cycle" do
    create(:preference_assessment, assessment_cycle: cycle)

    duplicate = build(:preference_assessment, assessment_cycle: cycle)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:assessment_cycle_id]).to be_present
  end

  it "reaches the student through its cycle (FR-049)" do
    assessment = create(:preference_assessment, assessment_cycle: cycle)

    expect(assessment.student).to eq(cycle.student)
    expect(assessment.student_id).to eq(cycle.student_id)
  end

  it "destroys its observations with it" do
    assessment = create(:preference_assessment, assessment_cycle: cycle)
    create(:preference_observation, preference_assessment: assessment)

    expect { assessment.destroy! }.to change(PreferenceObservation, :count).by(-1)
  end

  describe "#ranked_observations" do
    let(:assessment) { create(:preference_assessment, assessment_cycle: cycle) }

    it "filters by context and caps with a limit" do
      2.times do
        create(:preference_observation, preference_assessment: assessment,
                                        context: "play_time", duration_seconds: 30)
      end
      create(:preference_observation, preference_assessment: assessment,
                                      context: "circle_time", duration_seconds: 30)

      PreferenceAssessments::RankObservationsService.call(preference_assessment: assessment)

      expect(assessment.ranked_observations(context: "play_time").count).to eq(2)
      expect(assessment.ranked_observations(context: "play_time", limit: 1).count).to eq(1)
      expect(assessment.ranked_observations.count).to eq(3)
    end
  end

  describe "AssessmentCycle#preference_assessment!" do
    it "creates the draft once and returns it thereafter" do
      first = cycle.preference_assessment!

      expect { expect(cycle.preference_assessment!).to eq(first) }
        .not_to change(described_class, :count)
    end
  end
end
