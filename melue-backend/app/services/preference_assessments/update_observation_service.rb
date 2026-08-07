# frozen_string_literal: true

module PreferenceAssessments
  # Updates the timer, counter, approach flag or notes on an existing
  # observation (FR-047b, FR-047e), then refreshes ranks for its context.
  #
  # Values are absolute totals, not deltas, so a retried request leaves the
  # observation in the same state.
  class UpdateObservationService < ApplicationService
    # @param observation [PreferenceObservation]
    # @param attributes [Hash] any of :approached, :duration_seconds,
    #   :frequency_count, :notes. Keys with a nil value are ignored.
    def initialize(observation:, attributes:)
      @observation = observation
      @attributes  = attributes
    end

    def call
      assessment = @observation.preference_assessment

      unless assessment.status_draft?
        return failure("Preference assessment has already been submitted")
      end

      @observation.assign_attributes(@attributes.compact)

      return failure(@observation.errors.full_messages.join(", ")) unless @observation.save

      RankObservationsService.call(
        preference_assessment: assessment,
        context:               @observation.context
      )

      success(@observation.reload)
    end
  end
end
