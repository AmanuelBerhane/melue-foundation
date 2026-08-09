# frozen_string_literal: true

module PreferenceAssessments
  # Removes an observation from a draft assessment and re-ranks what remains.
  #
  # Mainly serves custom items (FR-047f), which a teacher may add by mistake
  # and cannot fix by deactivating a catalogue entry.
  class DeleteObservationService < ApplicationService
    # @param observation [PreferenceObservation]
    def initialize(observation:)
      @observation = observation
    end

    def call
      assessment = @observation.preference_assessment
      context    = @observation.context

      unless assessment.status_draft?
        return failure("Preference assessment has already been submitted")
      end

      @observation.destroy!

      RankObservationsService.call(preference_assessment: assessment, context: context)

      success(nil)
    rescue ActiveRecord::RecordNotDestroyed
      failure(@observation.errors.full_messages.join(", "))
    end
  end
end
