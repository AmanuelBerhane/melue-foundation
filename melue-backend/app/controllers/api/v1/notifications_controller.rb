# app/controllers/api/v1/notifications_controller.rb
module Api
  module V1
    class NotificationsController < Api::V1::BaseController
      before_action :authenticate_user!

      def index
        notifications = Notification.for_recipient(current_user.id)
                                    .order(created_at: :desc)
        render json: NotificationSerializer.new(notifications).as_json
      end

      def mark_as_read
        notification = Notification.for_recipient(current_user.id).find(params[:id])
        notification.mark_as_read!
        head :no_content
      end
    end
  end
end
