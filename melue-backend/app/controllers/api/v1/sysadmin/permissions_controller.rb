# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class PermissionsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_system_admin

        # Canonical modules matching Melue SRS (SCR-SYS-003, FR-016)
        MODULE_DEFINITIONS = [
          {
            id: "students",
            name: "Students / Enrollment",
            description: "Student records, enrollment pipeline, and documents",
            resources: %w[students enrollments forms]
          },
          {
            id: "assessments",
            name: "Clinical Assessments",
            description: "6-Week ABLLS skills, MASS/FAST behavior, and preference assessments",
            resources: %w[assessments skills_assessments behavior_assessments preference_assessments]
          },
          {
            id: "iups",
            name: "IUP & Goal Management",
            description: "IUP generation, Goal Bank, prompt levels, and mastery checks",
            resources: %w[iups goals goal_domains prompt_levels]
          },
          {
            id: "sessions",
            name: "Daily Active Therapy",
            description: "Session blocks, real-time trial logging, and session summaries",
            resources: %w[sessions trials session_summaries]
          },
          {
            id: "behavior_incidents",
            name: "Behavior & ABC Logging",
            description: "Behavior incident recording, ABC logs, and antecedent lists",
            resources: %w[behavior_incidents abc_lists]
          },
          {
            id: "staff",
            name: "Staff & Scheduling",
            description: "Staff accounts, teacher-student linking, and room capacity limits",
            resources: %w[staff_members staff_scheduling session_block_definitions session_schedule_configs]
          },
          {
            id: "reports",
            name: "Reports & Oversight",
            description: "Oversight analytics, bi-annual progress reports, and exports",
            resources: %w[reports oversight audit_logs]
          },
          {
            id: "parent_portal",
            name: "Parent Portal",
            description: "Guardian updates, home observations, and staff messaging",
            resources: %w[parent_communications home_observations]
          },
          {
            id: "admin",
            name: "System & Clinical Admin",
            description: "Role definitions, permissions configuration, and institutional settings",
            resources: %w[roles clinical_configs form_configurations]
          }
        ].freeze

        CANONICAL_ACTIONS = %w[view create edit delete approve].freeze

        ACTION_ALIASES = {
          "view"    => %w[view index show read],
          "create"  => %w[create],
          "edit"    => %w[edit update manage],
          "delete"  => %w[delete destroy],
          "approve" => %w[approve update_status]
        }.freeze

        # GET /api/v1/sysadmin/permissions
        def index
          ensure_catalog_permissions_exist!

          all_perms = Permission.order(:resource, :action).all
          grouped_by_resource = all_perms.group_by(&:resource)

          modules_data = MODULE_DEFINITIONS.map do |mod|
            primary_resource = mod[:id]
            all_module_resources = mod[:resources]

            # Find or build permissions for each canonical action
            permissions_for_actions = CANONICAL_ACTIONS.map do |action|
              # Look for primary permission (e.g. students:view)
              perm = all_perms.find { |p| p.resource == primary_resource && p.action == action }

              # If not found, look among aliases or secondary resources
              unless perm
                aliases = ACTION_ALIASES[action] || [ action ]
                perm = all_perms.find do |p|
                  all_module_resources.include?(p.resource) && aliases.include?(p.action)
                end
              end

              {
                id: perm&.id&.to_s,
                action: action,
                action_label: action.upcase,
                resource: primary_resource,
                name: "#{primary_resource}:#{action}"
              }
            end

            {
              id: mod[:id],
              name: mod[:name],
              description: mod[:description],
              resource: primary_resource,
              permissions: permissions_for_actions
            }
          end

          render json: {
            modules: modules_data,
            actions: CANONICAL_ACTIONS.map(&:upcase),
            all_permissions: all_perms.map { |p|
              { id: p.id.to_s, resource: p.resource, action: p.action, name: "#{p.resource}:#{p.action}" }
            }
          }
        end

        private

        def ensure_catalog_permissions_exist!
          MODULE_DEFINITIONS.each do |mod|
            res = mod[:id]
            CANONICAL_ACTIONS.each do |act|
              Permission.find_or_create_by!(resource: res, action: act) do |p|
                p.description = "#{act.capitalize} permission for #{mod[:name]}"
              end
            end
          end
        end

        def require_system_admin
          return if current_user&.has_any_role?(
            Role::Names::SYSTEM_ADMIN,
            Role::Names::INSTITUTIONAL_ADMIN
          )

          render json: { error: "Forbidden: Administrator access required" }, status: :forbidden
        end
      end
    end
  end
end
