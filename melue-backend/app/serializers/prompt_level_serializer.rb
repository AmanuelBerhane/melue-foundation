# frozen_string_literal: true

class PromptLevelSerializer < ApplicationSerializer
  private

  def serialize(prompt_level)
    {
      id: prompt_level.id,
      label: prompt_level.label,
      color: prompt_level.color,
      display_order: prompt_level.display_order,
      is_active: prompt_level.is_active
    }
  end
end
