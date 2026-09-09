# frozen_string_literal: true

module PreferenceAssessments
  # Finalises a preference assessment (FR-036, FR-049).
  #
  # Ranks are recomputed across all three contexts immediately before the
  # status flips, so the submitted record is internally consistent even if the
  # last write happened to skip a re-rank.
  #
  # FR-050 — marking the parent cycle complete once skills, behaviour and
  # preference are all submitted — is handled by the PreferenceAssessment
  # after-save hook.
  class SubmitService < ApplicationService
    # @param preference_assessment [PreferenceAssessment]
    def initialize(preference_assessment:)
      @preference_assessment = preference_assessment
    end

    def call
      unless @preference_assessment.status_draft?
        return failure("Preference assessment has already been submitted")
      end

      if @preference_assessment.preference_observations.empty?
        return failure("At least one observation is required before submitting")
      end

      PreferenceAssessment.transaction do
        RankObservationsService.call(preference_assessment: @preference_assessment)
        @preference_assessment.update!(status: "submitted", submitted_at: Time.current)
      end

      success(@preference_assessment)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end
  end
end
