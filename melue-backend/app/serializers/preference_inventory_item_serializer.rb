# frozen_string_literal: true

class PreferenceInventoryItemSerializer < ApplicationSerializer
  private

  def serialize(item)
    {
      id:       item.id,
      name:     item.name,
      category: item.category
    }
  end
end
