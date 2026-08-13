# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreferenceAssessments::SubmitService, type: :service do
  let(:assessment) { create(:preference_assessment) }

  it "submits and stamps the time" do
    create(:preference_observation, preference_assessment: assessment, duration_seconds: 20)

    result = described_class.call(preference_assessment: assessment)

    expect(result).to be_success
    expect(assessment.reload).to be_status_submitted
    expect(assessment.submitted_at).to be_present
  end

  it "re-ranks every context before finalising" do
    low  = create(:preference_observation, preference_assessment: assessment,
                                           duration_seconds: 10, frequency_count: 1)
    high = create(:preference_observation, preference_assessment: assessment,
                                           duration_seconds: 400, frequency_count: 30)

    described_class.call(preference_assessment: assessment)

    expect(high.reload.rank).to eq(1)
    expect(low.reload.rank).to eq(2)
  end

  it "refuses an assessment with no observations" do
    result = described_class.call(preference_assessment: assessment)

    expect(result).to be_failure
    expect(result.error).to eq("At least one observation is required before submitting")
    expect(assessment.reload).to be_status_draft
  end

  it "refuses to submit twice" do
    create(:preference_observation, preference_assessment: assessment)
    described_class.call(preference_assessment: assessment)

    result = described_class.call(preference_assessment: assessment)

    expect(result).to be_failure
    expect(result.error).to eq("Preference assessment has already been submitted")
  end
end
