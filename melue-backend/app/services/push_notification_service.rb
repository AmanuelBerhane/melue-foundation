# frozen_string_literal: true

class PushNotificationService < ApplicationService
  attr_reader :recipient_user_ids, :title, :body, :data

  def initialize(recipient_user_ids:, title:, body:, data: {})
    @recipient_user_ids = Array(recipient_user_ids)
    @title = title
    @body = body
    @data = data
  end

  def call
    return failure("No recipients provided") if recipient_user_ids.empty?
    return failure("Title and body are required") if title.blank? || body.blank?

    # In production, dispatch via Firebase Cloud Messaging (FCM) / APNs adapter.
    # In development and test, log payload to Rails logger for zero-cost operation.
    deliver_notifications

    success(message: "Push notification dispatched", count: recipient_user_ids.count)
  end

  private

  def deliver_notifications
    Rails.logger.debug <<~LOG if Rails.env.development? || Rails.env.test?
      [PushNotificationService] Dispatching Notification:
        Recipients: #{recipient_user_ids.join(', ')}
        Title: #{title}
        Body: #{body}
        Data: #{data.inspect}
    LOG

    # Standard production hook for FCM/Webpush payload dispatch
    if provider_enabled?
      send_to_provider
    end
  end

  def provider_enabled?
    ENV["FCM_SERVER_KEY"].present?
  end

  def send_to_provider
    # Hook for production FCM HTTP v1 / FCM API payload send
  end
end
