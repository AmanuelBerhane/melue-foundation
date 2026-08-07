# frozen_string_literal: true

# The ranked top-preferences row defined by FR-047d: rank number, item name,
# category, total duration and frequency count. Tier and combined score are
# included so the client can group by "Highest / Moderately / Low Preferred"
# without recomputing anything.
class PreferenceRankingSerializer < ApplicationSerializer
  private

  def serialize(observation)
    {
      rank:             observation.rank,
      item_name:        observation.item_name,
      item_category:    observation.item_category,
      context:          observation.context,
      duration_seconds: observation.duration_seconds,
      frequency_count:  observation.frequency_count,
      combined_score:   observation.combined_score.to_f,
      tier:             observation.tier,
      custom_item:      observation.custom_item?
    }
  end
end
