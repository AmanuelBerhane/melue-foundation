# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class AuditLogsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_system_admin_or_institutional_admin

        # GET /api/v1/sysadmin/audit-logs
        def index
          logs = AuditLog.includes(:user).order(created_at: :desc).limit(200)

          if params[:user].present? && params[:user] != "All"
            logs = logs.joins(:user).where("users.email ILIKE ?", "%#{params[:user]}%")
          end

          if params[:action].present? && params[:action] != "All"
            act = params[:action].to_s.downcase
            action_candidates = case act
            when "created" then %w[created create]
            when "updated" then %w[updated update update_permissions]
            when "deleted" then %w[deleted destroy]
            when "changed" then %w[changed change]
            else [ act ]
            end
            logs = logs.where(action: action_candidates)
          end

          if params[:search].present? && params[:search].to_s.strip.present?
            term = "%#{params[:search].to_s.strip}%"
            logs = logs.left_joins(:user).where(
              "audit_logs.resource_type ILIKE :term OR audit_logs.resource_id ILIKE :term OR users.email ILIKE :term",
              term: term
            )
          end

          render json: logs.map { |log| serialize_audit_log(log) }
        end

        private

        def require_system_admin_or_institutional_admin
          return if current_user&.has_any_role?(
            Role::Names::SYSTEM_ADMIN,
            Role::Names::INSTITUTIONAL_ADMIN
          )

          render json: { error: "Forbidden: Administrator access required" }, status: :forbidden
        end

        def serialize_audit_log(log)
          action_map = {
            "create" => "created",
            "update" => "updated",
            "update_permissions" => "updated",
            "destroy" => "deleted",
            "change" => "changed"
          }

          user_display = if log.user
            staff = StaffMember.find_by(user_id: log.user.id)
            staff&.full_name.presence || log.user.email
          else
            "System Admin"
          end

          resource_str = if log.metadata.is_a?(Hash) && log.metadata["role_name"].present?
            "Role: #{log.metadata['role_name']}"
          elsif log.metadata.is_a?(Hash) && log.metadata["resource"].present?
            log.metadata["resource"]
          elsif log.resource_type.present?
            "#{log.resource_type} ##{log.resource_id}".strip
          else
            "System"
          end

          {
            id: "aud-#{log.id}",
            user: user_display,
            action: action_map[log.action] || log.action,
            date: log.created_at.strftime("%Y-%m-%d"),
            time: log.created_at.strftime("%I:%M %p"),
            resource: resource_str,
            ip: (log.metadata.is_a?(Hash) && log.metadata["ip"]) || "192.168.1.10",
            oldValue: log.change_data.is_a?(Hash) ? (log.change_data["old"] || log.change_data["removed"]&.to_s) : nil,
            newValue: log.change_data.is_a?(Hash) ? (log.change_data["new"] || log.change_data["added"]&.to_s) : (log.metadata.is_a?(Hash) ? log.metadata["newValue"] : nil)
          }
        end
      end
    end
  end
end
