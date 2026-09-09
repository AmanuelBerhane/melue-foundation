# frozen_string_literal: true

# Serializes individual ABLLS response updates.
class AbllsResponseSerializer < ApplicationSerializer
  private

  def serialize(response)
    {
      id: response.id,
      skill_item: {
        id:          response.ablls_skill_item.id,
        identifier:  response.ablls_skill_item.identifier,
        description: response.ablls_skill_item.description
      },
      score:      response.score,
      note:       response.note,
      updated_at: response.updated_at
    }
  end
end
