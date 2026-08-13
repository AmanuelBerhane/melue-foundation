# frozen_string_literal: true

class PreferenceObservationSerializer < ApplicationSerializer
  private

  def serialize(observation)
    {
      id:                          observation.id,
      context:                     observation.context,
      preference_inventory_item_id: observation.preference_inventory_item_id,
      item_name:                   observation.item_name,
      item_category:               observation.item_category,
      custom_item:                 observation.custom_item?,
      approached:                  observation.approached,
      duration_seconds:            observation.duration_seconds,
      frequency_count:             observation.frequency_count,
      combined_score:              observation.combined_score.to_f,
      tier:                        observation.tier,
      rank:                        observation.rank,
      notes:                       observation.notes
    }
  end
end
