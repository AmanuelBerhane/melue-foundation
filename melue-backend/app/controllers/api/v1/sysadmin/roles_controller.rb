# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class RolesController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_system_admin
        before_action :set_role, only: %i[show update destroy permissions update_permissions permissions_audit reset_default_permissions copy_permissions]

        # GET /api/v1/sysadmin/roles
        def index
          roles = Role.all
          user_counts = RoleAssignment
            .joins(:user)
            .left_joins(user: :staff_member)
            .where(role_assignments: { revoked_at: nil })
            .where(users: { status: :verified })
            .where("staff_members.id IS NULL OR staff_members.discarded_at IS NULL")
            .group(:role_id)
            .count
          render json: roles.map { |r| serialize_role(r, user_count: user_counts[r.id] || 0) }
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
            render json: { error: role.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/sysadmin/roles/:id
        def update
          if @role.update(role_params)
            render json: serialize_role(@role)
          else
            render json: { error: @role.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/sysadmin/roles/:id
        def destroy
          if @role.is_system_critical?
            return render json: { error: "System critical roles cannot be deleted" }, status: :unprocessable_content
          end

          @role.destroy
          render json: { deleted: true }
        end

        # GET /api/v1/sysadmin/roles/:id/permissions
        def permissions
          Permission.ensure_catalog_exists!
          permissions = @role.permissions.map do |p|
            { id: p.id, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
          end
          render json: { roleId: @role.id, permissions: permissions }
        end

        # POST /api/v1/sysadmin/roles/:id/permissions
        def update_permissions
          Permission.ensure_catalog_exists!

          raw_identifiers = if params[:permission_ids].present?
            Array(params[:permission_ids]).map(&:to_s)
          else
            []
          end

          resolved_perms = []
          raw_identifiers.each do |id_or_tag|
            if id_or_tag.include?(":")
              res, act = id_or_tag.split(":", 2)
              p = Permission.find_by(resource: res, action: act.downcase)
              if p.nil?
                canonical_res = RESOURCE_ALIAS_MAP[res.downcase]
                p = Permission.find_by(resource: canonical_res, action: act.downcase) if canonical_res
              end
              resolved_perms << p if p
            elsif id_or_tag =~ UUID_REGEX
              p = Permission.find_by(id: id_or_tag)
              resolved_perms << p if p
            end
          end

          if params[:matrix].is_a?(Hash)
            params[:matrix].each do |mod, acts|
              next unless acts.is_a?(Hash)
              acts.each do |act, enabled|
                next unless enabled == true || enabled == "true"
                perm = Permission.find_by(resource: mod.to_s, action: act.to_s.downcase)
                if perm.nil?
                  canonical_res = RESOURCE_ALIAS_MAP[mod.to_s.downcase]
                  perm = Permission.find_by(resource: canonical_res, action: act.to_s.downcase) if canonical_res
                end
                resolved_perms << perm if perm
              end
            end
          end

          new_permissions = resolved_perms.uniq

          old_ids = @role.permission_ids.map(&:to_s).sort
          new_ids = new_permissions.map { |p| p.id.to_s }.sort

          ActiveRecord::Base.transaction do
            @role.permissions = new_permissions

            AuditLog.create!(
              user: current_user,
              action: "update_permissions",
              resource_type: "Role",
              resource_id: @role.id.to_s,
              change_data: { added: (new_ids - old_ids), removed: (old_ids - new_ids) },
              metadata: { role_name: @role.name, updated_by: current_user.email }
            )
          end

          render json: {
            status: "ok",
            roleId: @role.id,
            permissions: @role.permissions.reload.map { |p|
              { id: p.id, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
            }
          }
        end

        # POST /api/v1/sysadmin/roles/:id/permissions/reset_default
        def reset_default_permissions
          default_permissions = default_permissions_for_role(@role)

          old_ids = @role.permission_ids.map(&:to_s).sort
          new_ids = default_permissions.pluck(:id).map(&:to_s).sort

          ActiveRecord::Base.transaction do
            @role.permissions = default_permissions

            AuditLog.create!(
              user: current_user,
              action: "reset_default_permissions",
              resource_type: "Role",
              resource_id: @role.id.to_s,
              change_data: { added: (new_ids - old_ids), removed: (old_ids - new_ids) },
              metadata: { role_name: @role.name, updated_by: current_user.email, template: "reset_default" }
            )
          end

          render json: {
            status: "ok",
            roleId: @role.id,
            permissions: @role.permissions.reload.map { |p|
              { id: p.id, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
            }
          }
        end

        # POST /api/v1/sysadmin/roles/:id/permissions/copy_from
        def copy_permissions
          source_role_id = params[:source_role_id].presence || params[:sourceRoleId]
          source_role = Role.find_by(id: source_role_id)

          unless source_role
            return render json: { error: "Source role not found" }, status: :not_found
          end

          old_ids = @role.permission_ids.map(&:to_s).sort
          new_ids = source_role.permission_ids.map(&:to_s).sort

          ActiveRecord::Base.transaction do
            @role.permissions = source_role.permissions

            AuditLog.create!(
              user: current_user,
              action: "copy_permissions",
              resource_type: "Role",
              resource_id: @role.id.to_s,
              change_data: { added: (new_ids - old_ids), removed: (old_ids - new_ids), source_role_id: source_role.id.to_s },
              metadata: { role_name: @role.name, source_role_name: source_role.name, updated_by: current_user.email }
            )
          end

          render json: {
            status: "ok",
            roleId: @role.id,
            permissions: @role.permissions.reload.map { |p|
              { id: p.id, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
            }
          }
        end

        # GET /api/v1/sysadmin/roles/:id/permissions/audit
        def permissions_audit
          logs = AuditLog.where(resource_type: "Role", resource_id: @role.id.to_s, action: %w[update_permissions reset_default_permissions copy_permissions])
                         .order(created_at: :desc)
                         .limit(50)

          render json: logs.map { |log|
            {
              id: log.id,
              action: log.action,
              changed_by: log.user&.email,
              change_data: log.change_data,
              metadata: log.metadata,
              created_at: log.created_at
            }
          }
        end

        UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

        RESOURCE_ALIAS_MAP = {
          "sys_staff_accounts" => "staff_members",
          "sys_role_management" => "roles",
          "sys_permissions" => "clinical_configs",
          "sys_audit_log" => "audit_logs",
          "ia_form_builder" => "form_configurations",
          "ia_trial_logging" => "prompt_levels",
          "ia_abc_dropdowns" => "abc_lists",
          "ia_schedule_capacity" => "session_schedule_configs",
          "director_scheduling" => "staff_scheduling",
          "coord_staff_workload" => "staff",
          "coord_room_scheduling" => "session_block_definitions",
          "pd_enrollment_wizard" => "enrollments",
          "coord_student_registration" => "enrollments",
          "teacher_assessments" => "assessments",
          "pd_assessment_review" => "assessments",
          "pd_assessment_summary" => "assessments",
          "pd_iup_generation" => "iups",
          "pd_iup_library" => "iups",
          "pd_clinical_quality" => "goals",
          "teacher_daily_trials" => "trials",
          "teacher_daily_notes" => "sessions",
          "teacher_abc_log" => "abc_lists",
          "coord_live_sessions" => "sessions",
          "coord_session_summary" => "session_summaries",
          "goal_mastery_approval" => "goals",
          "director_parent_comm" => "parent_communications",
          "parent_child_progress" => "parent_portal",
          "parent_home_observations" => "home_observations",
          "director_reports_oversight" => "oversight",
          "director_report_builder" => "reports",
          "enrollments" => "students",
          "forms" => "students",
          "skills_assessments" => "assessments",
          "behavior_assessments" => "assessments",
          "preference_assessments" => "assessments",
          "goals" => "iups",
          "goal_domains" => "iups",
          "prompt_levels" => "iups",
          "trials" => "sessions",
          "session_summaries" => "sessions",
          "abc_lists" => "behavior_incidents",
          "staff_members" => "staff",
          "staff_scheduling" => "staff",
          "session_block_definitions" => "staff",
          "session_schedule_configs" => "staff",
          "oversight" => "reports",
          "audit_logs" => "reports",
          "parent_communications" => "parent_portal",
          "home_observations" => "parent_portal",
          "roles" => "admin",
          "clinical_configs" => "admin",
          "form_configurations" => "admin"
        }.freeze

        private

        def set_role
          role_id_or_name = params[:id].to_s.strip
          @role = if role_id_or_name =~ UUID_REGEX
            Role.find_by(id: role_id_or_name)
          else
            Role.find_by("LOWER(name) = ?", role_id_or_name.downcase.tr("_", " ")) ||
            Role.find_by("LOWER(REPLACE(REPLACE(name, ' ', '_'), '-', '_')) = ?", role_id_or_name.downcase) ||
            Role.find_by(name: role_id_or_name)
          end

          return if @role

          render json: { error: "Role not found" }, status: :not_found
        end

        def role_params
          params.permit(:name, :description)
        end

        def serialize_role(role, user_count: nil)
          {
            id: role.id.to_s,
            name: role.name,
            description: role.respond_to?(:description) ? role.description : role.name,
            is_system_critical: role.is_system_critical,
            user_count: user_count || role.users.count,
            permission_count: role.permissions.count,
            has_permissions: role.permissions.exists?
          }
        end

        def require_system_admin
          return if current_user&.has_any_role?(
            Role::Names::SYSTEM_ADMIN,
            Role::Names::INSTITUTIONAL_ADMIN
          )

          render json: { error: "Forbidden: Administrator access required" }, status: :forbidden
        end

        def default_permissions_for_role(role)
          Permission.ensure_catalog_exists!
          all_perms = Permission.all

          case role.name
          when Role::Names::SYSTEM_ADMIN
            all_perms.where(resource: %w[staff_members roles clinical_configs audit_logs])
          when Role::Names::INSTITUTIONAL_ADMIN
            all_perms.where(resource: %w[session_schedule_configs staff_scheduling form_configurations forms abc_lists behavior_incidents prompt_levels sessions goal_domains goals iups])
          when Role::Names::DIRECTOR
            all_perms.where(resource: %w[students assessments iups sessions behavior_incidents staff_scheduling session_schedule_configs reports oversight goals parent_communications parent_portal])
          when Role::Names::PROGRAM_DIRECTOR
            all_perms.where(resource: %w[students enrollments forms assessments skills_assessments behavior_assessments preference_assessments iups goals goal_domains reports oversight], action: %w[view create edit approve index show update])
          when Role::Names::THERAPY_COORDINATOR
            all_perms.where(resource: %w[students enrollments sessions trials session_summaries behavior_incidents staff_scheduling session_block_definitions reports parent_communications parent_portal], action: %w[view create edit index show update])
          when Role::Names::TEACHER
            all_perms.where(resource: %w[sessions behavior_incidents], action: %w[view create edit index show update])
                     .or(all_perms.where(resource: %w[students assessments iups], action: %w[view index show]))
          when Role::Names::PARENT
            all_perms.where(resource: %w[parent_portal reports sessions], action: %w[view create index show])
          else
            # Custom roles default to standard active therapy and student viewing
            all_perms.where(resource: %w[sessions students behavior_incidents], action: %w[view create edit index show update])
          end
        end
      end
    end
  end
end
