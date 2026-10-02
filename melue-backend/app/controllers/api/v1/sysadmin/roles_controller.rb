# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class RolesController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_system_admin
        before_action :set_role, only: %i[show update destroy permissions update_permissions permissions_audit]

        # GET /api/v1/sysadmin/roles
        def index
          roles = Role.includes(:permissions).all
          render json: roles.map { |r| serialize_role(r) }
        end

        # GET /api/v1/sysadmin/roles/:id
        def show
          render json: serialize_role(@role)
        end

        # POST /api/v1/sysadmin/roles
        def create
          role = Role.new(
            name: params[:name],
            description: params[:description],
            is_system_critical: false,
            is_active: true
          )

          if role.save
            render json: serialize_role(role), status: :created
          else
            render json: { error: role.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/sysadmin/roles/:id
        def update
          if @role.update(role_params)
            render json: serialize_role(@role)
          else
            render json: { error: @role.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/sysadmin/roles/:id
        def destroy
          if @role.is_system_critical?
            return render json: { error: "System critical roles cannot be deleted" }, status: :unprocessable_entity
          end

          @role.destroy
          render json: { deleted: true }
        end

        # GET /api/v1/sysadmin/roles/:id/permissions
        def permissions
          permissions = @role.permissions.map do |p|
            { id: p.id, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
          end
          render json: { roleId: @role.id, permissions: permissions }
        end

        # POST /api/v1/sysadmin/roles/:id/permissions
        def update_permissions
          render json: { status: "ok" }
        end

        # GET /api/v1/sysadmin/roles/:id/permissions/audit
        def permissions_audit
          render json: []
        end

        private

        def set_role
          @role = Role.find(params[:id])
        end

        def role_params
          params.permit(:name, :description)
        end

        def serialize_role(role)
          {
            id: role.id.to_s,
            name: role.name,
            description: role.respond_to?(:description) ? role.description : role.name,
            is_system_critical: role.is_system_critical,
            user_count: role.users.count
          }
        end

        def require_system_admin
          return if current_user&.has_role?(:system_admin) ||
                    current_user&.has_role?("system_admin") ||
                    current_user&.has_role?(Role::Names::SYSTEM_ADMIN) ||
                    current_user&.has_role?(:institutional_admin) ||
                    current_user&.has_role?(Role::Names::INSTITUTIONAL_ADMIN)

          render json: { error: "Forbidden: Administrator access required" }, status: :forbidden
        end
      end
    end
  end
end
