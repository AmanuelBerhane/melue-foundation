# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "no-reply@melue.foundation")

def account_created(user)
  @user = user
  mail(to: @user.email, subject: "Welcome to Melue Foundation Therapy Management System", body: "Your account has been created for #{@user.email}.")
end

  def password_reset_requested(user, reset_url)
    @user = user
    @reset_url = reset_url
    mail(to: @user.email, subject: "Password Reset Request - Melue Foundation")
  end

  def system_alert(user, alert_title, alert_message)
    @user = user
    @alert_title = alert_title
    @alert_message = alert_message
    mail(to: @user.email, subject: "System Alert: #{alert_title}")
  end
end
