# frozen_string_literal: true

class NotificationSerializer < ApplicationSerializer
  private

  def serialize(notification)
    {
      id:               notification.id,
      type:             notification.type,
      payload:          notification.payload,
      read:             notification.read?,
      read_at:          notification.read_at,
      created_at:       notification.created_at
    }
  end
end
