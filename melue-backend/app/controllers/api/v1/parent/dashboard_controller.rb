# frozen_string_literal: true

module Api
  module V1
    module Parent
      # SCR-PAR-001 — Parent Dashboard
      class DashboardController < BaseController
        # @oas_include
        # @summary Guardian overview: profile, children and unread counts
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @response Success (200) [Hash{ data: Hash{ guardian: Hash, students: Array<Hash>, unread_notifications: Integer, unread_messages: Integer } }]
        # @response Forbidden (403) [Hash{ error: String }]
        # GET /api/v1/parent/dashboard
        def index
          students = current_guardian.students.kept.order(:first_name, :last_name)

          render json: {
            data: {
              guardian: GuardianSerializer.new(current_guardian).as_json,
              students: StudentSerializer.new(students, profile: true).as_json,
              unread_notifications: Notification.for_recipient(current_user.id).unread.count,
              unread_messages: current_guardian.parent_communications.direction_outbound.unread.count
            }
          }
        end
      end
    end
  end
end
