# frozen_string_literal: true

module PreferenceAssessments
  # Records an item into a context, creating the observation or updating the
  # one already there (FR-047b, FR-047e, FR-047f).
  #
  # The call is an upsert on (assessment, context, item) so a teacher tapping
  # the same item twice never produces a duplicate row, and a retried request
  # after a dropped connection is safe. Duration and frequency are absolute
  # totals rather than deltas, which keeps repeat submissions idempotent.
  #
  # Ranks are refreshed for the affected context on every successful write
  # (FR-048).
  class RecordObservationService < ApplicationService
    # @param preference_assessment [PreferenceAssessment]
    # @param context [String] 'sensory_time' | 'circle_time' | 'play_time'
    # @param preference_inventory_item_id [String, nil] catalogue item UUID
    # @param custom_item_name [String, nil] teacher-supplied item (FR-047f)
    # @param custom_item_category [String, nil] category for the custom item
    # @param approached [Boolean, nil] Approached / Did-Not-Approach
    # @param duration_seconds [Integer, nil] accumulated timer total
    # @param frequency_count [Integer, nil] accumulated counter total
    # @param notes [String, nil] per-item notes (FR-047e)
    def initialize(preference_assessment:, context:,
                   preference_inventory_item_id: nil, custom_item_name: nil,
                   custom_item_category: nil, approached: nil,
                   duration_seconds: nil, frequency_count: nil, notes: nil)
      @preference_assessment        = preference_assessment
      @context                      = context
      @preference_inventory_item_id = preference_inventory_item_id
      @custom_item_name             = custom_item_name.presence
      @custom_item_category         = custom_item_category
      @approached                   = approached
      @duration_seconds             = duration_seconds
      @frequency_count              = frequency_count
      @notes                        = notes
    end

    def call
      unless @preference_assessment.status_draft?
        return failure("Preference assessment has already been submitted")
      end

      unless PreferenceAssessment::CONTEXTS.include?(@context)
        return failure("Context must be one of: #{PreferenceAssessment::CONTEXTS.join(', ')}")
      end

      item = nil
      if @preference_inventory_item_id.present?
        item = PreferenceInventoryItem.find_by(id: @preference_inventory_item_id, is_active: true)
        return failure("Inventory item not found or inactive") unless item
      elsif @custom_item_name.blank?
        return failure("An inventory item or a custom item name is required")
      end

      observation = find_or_initialize(item)
      apply_attributes(observation, item)

      return failure(observation.errors.full_messages.join(", ")) unless observation.save

      RankObservationsService.call(
        preference_assessment: @preference_assessment,
        context:               @context
      )

      success(observation.reload)
    rescue ActiveRecord::RecordNotUnique
      failure("This item has already been recorded for this context")
    end

    private

    def find_or_initialize(item)
      scope = @preference_assessment.preference_observations.where(context: @context)

      existing =
        if item
          scope.find_by(preference_inventory_item_id: item.id)
        else
          scope.where(preference_inventory_item_id: nil)
               .find_by(custom_item_name: @custom_item_name)
        end

      existing || @preference_assessment.preference_observations.new(context: @context)
    end

    # Only fields the caller actually supplied are written, so a request that
    # bumps the counter does not wipe notes recorded a moment earlier.
    def apply_attributes(observation, item)
      if item
        observation.preference_inventory_item = item
        observation.custom_item_name          = nil
        observation.custom_item_category      = nil
      else
        observation.preference_inventory_item = nil
        observation.custom_item_name          = @custom_item_name
        observation.custom_item_category      = @custom_item_category unless @custom_item_category.nil?
      end

      observation.approached       = @approached       unless @approached.nil?
      observation.duration_seconds = @duration_seconds unless @duration_seconds.nil?
      observation.frequency_count  = @frequency_count  unless @frequency_count.nil?
      observation.notes            = @notes            unless @notes.nil?
    end
  end
end
