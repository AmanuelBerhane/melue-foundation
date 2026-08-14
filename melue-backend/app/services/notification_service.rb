class NotificationService
  def self.notify(recipient:, type:, payload:)
    notification = Notification.create!(
      recipient_user_id: recipient.id,
      type: type,
      payload_reference: payload.to_json
    )

    PushNotificationJob.perform_later(notification.id)
    notification
  end
end
