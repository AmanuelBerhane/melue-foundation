class PushNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return if notification.read?

    # Swap in FCM/APNs client here. Keep this job dumb —
    # it just resolves the device token and hands off.
    PushDeliveryAdapter.deliver(
      user_id: notification.recipient_user_id,
      title: title_for(notification.type),
      body: body_for(notification)
    )
  end

  private

  def title_for(type)
    { "draft_reminder" => "Draft reminder",
      "mastery_approval" => "Mastery check needs approval",
      "session_submission" => "New session submitted",
      "parent_communication" => "New message from guardian" }.fetch(type, "Notification")
  end

  def body_for(notification)
    notification.payload["summary"] || "You have a new update."
  end
end
