# frozen_string_literal: true

require "bcrypt"

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File 1/4: db/seeds/01_credentials_and_users.rb
#
# Scope:
#   1. Core RBAC Roles (7 standard roles per FR-016 / System Architecture)
#   2. Complete Granular Permissions Matrix (Canonical + REST actions)
#   3. Role-Permission Assignments
#   4. Authentic Staff Accounts (Tihut Girma, Hana Kebede, Mibret Zenebe, etc.)
#   5. Authentic Guardian/Parent Account (Parent of Adel)
#   6. Role Assignments (RoleAssignment & UserRole synchronization)
# ==============================================================================

puts "\n" + ("=" * 80)
puts "  [SEED 01/04] CREDENTIALS, ROLES, RBAC PERMISSIONS & USERS"
puts ("=" * 80)

ActiveRecord::Base.transaction do
  SEED_PASSWORD = "Password123!"
  hashed_password = BCrypt::Password.create(SEED_PASSWORD)

  # ----------------------------------------------------------------------------
  # 1. Core RBAC Roles (7 Standard Roles)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning 7 Standard Roles..."

  role_definitions = [
    {
      name: Role::Names::SYSTEM_ADMIN,
      is_system_critical: true,
      description: "Full system administration, security controls, RBAC management, and global audit logging."
    },
    {
      name: Role::Names::INSTITUTIONAL_ADMIN,
      is_system_critical: true,
      description: "Facility administration, staff provisioning, institutional governance, and clinical compliance."
    },
    {
      name: Role::Names::DIRECTOR,
      is_system_critical: false,
      description: "Executive oversight, organizational reporting, director approvals, and executive dashboards."
    },
    {
      name: Role::Names::PROGRAM_DIRECTOR,
      is_system_critical: false,
      description: "Clinical program leadership, IUP reviews/approvals, assessment governance, and goal banks."
    },
    {
      name: Role::Names::THERAPY_COORDINATOR,
      is_system_critical: false,
      description: "Daily therapy scheduling, caseload management, room/station allocations, and active session review."
    },
    {
      name: Role::Names::TEACHER,
      is_system_critical: false,
      description: "One-to-one clinical therapy execution, real-time trial data logging, and ABC incident logging."
    },
    {
      name: Role::Names::PARENT,
      is_system_critical: false,
      description: "Parent portal access for child progress monitoring, home observations, and staff messaging."
    }
  ]

  roles_map = {}
  role_definitions.each do |r_attrs|
    role = Role.find_or_initialize_by(name: r_attrs[:name])
    role.is_system_critical = r_attrs[:is_system_critical]
    role.is_active          = true
    role.description        = r_attrs[:description]
    role.save!
    roles_map[r_attrs[:name]] = role
  end

  puts "    ✓ #{roles_map.size} standard roles synchronized."

  # ----------------------------------------------------------------------------
  # 2. Permissions Catalog (FR-016: View, Create, Edit, Delete, Approve + REST)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Comprehensive Permissions Catalog..."

  # Resources representing all backend controllers, entities, and UI modules
  resources = %w[
    students
    enrollments
    forms
    assessments
    skills_assessments
    behavior_assessments
    preference_assessments
    iups
    goals
    goal_domains
    prompt_levels
    sessions
    trials
    session_summaries
    behavior_incidents
    abc_lists
    staff_members
    staff_scheduling
    session_block_definitions
    session_schedule_configs
    reports
    oversight
    audit_logs
    parent_communications
    home_observations
    roles
    clinical_configs
    form_configurations
    staff
    admin
    parent_portal
  ].uniq

  # Comprehensive actions spanning canonical UI verbs and RESTful operations
  actions = %w[
    view
    create
    edit
    delete
    approve
    index
    show
    update
    destroy
    manage
    update_status
    reset_password
    reorder
    import
    export
  ].uniq

  permission_catalog = {}
  resources.each do |res|
    actions.each do |act|
      perm = Permission.find_or_initialize_by(resource: res, action: act)
      perm.description = "Can #{act} #{res}" if perm.description.blank?
      perm.save!
      permission_catalog["#{res}:#{act}"] = perm
    end
  end

  puts "    ✓ #{permission_catalog.size} granular permissions registered."

  # ----------------------------------------------------------------------------
  # 3. Role-Permission Mappings
  # ----------------------------------------------------------------------------
  puts "\n--> Mapping Permissions to Roles..."

  existing_role_perms = RolePermission.pluck(:role_id, :permission_id).to_set
  role_perms_to_insert = []

  grant_permissions = lambda do |role, rule_hash|
    rule_hash.each do |res, acts|
      acts.each do |act|
        perm = permission_catalog["#{res}:#{act}"]
        next unless perm

        pair = [ role.id, perm.id ]
        unless existing_role_perms.include?(pair)
          role_perms_to_insert << {
            role_id: role.id,
            permission_id: perm.id,
            created_at: Time.current,
            updated_at: Time.current
          }
          existing_role_perms.add(pair)
        end
      end
    end
  end

  # Helpers for common action groupings
  all_actions = actions
  crud_approve = %w[view create edit delete approve index show update destroy manage]
  view_and_edit = %w[view edit index show update manage]
  view_only = %w[view index show]

  # 3a. System Administrator — Full unrestricted system access
  all_resources_full_access = resources.each_with_object({}) { |r, h| h[r] = all_actions }
  grant_permissions.call(roles_map[Role::Names::SYSTEM_ADMIN], all_resources_full_access)

  # 3b. Institutional Administrator — Complete institutional, clinical, and user management
  grant_permissions.call(roles_map[Role::Names::INSTITUTIONAL_ADMIN], all_resources_full_access)

  # 3c. Executive Director — Foundation-wide operational, clinical, and financial oversight
  director_perms = {
    "students"                  => crud_approve,
    "enrollments"               => crud_approve,
    "forms"                     => crud_approve + %w[import export],
    "assessments"               => crud_approve,
    "skills_assessments"        => crud_approve,
    "behavior_assessments"      => crud_approve,
    "preference_assessments"    => crud_approve,
    "iups"                      => crud_approve,
    "goals"                     => crud_approve,
    "goal_domains"              => crud_approve,
    "prompt_levels"             => crud_approve,
    "sessions"                  => crud_approve,
    "trials"                    => view_only,
    "session_summaries"         => crud_approve,
    "behavior_incidents"        => crud_approve,
    "abc_lists"                 => crud_approve,
    "staff_members"             => crud_approve + %w[reset_password],
    "staff_scheduling"          => crud_approve,
    "session_block_definitions" => crud_approve,
    "session_schedule_configs"  => crud_approve,
    "reports"                   => all_actions,
    "oversight"                 => all_actions,
    "audit_logs"                => view_only,
    "parent_communications"     => view_only,
    "home_observations"         => view_only,
    "roles"                     => view_only + %w[manage],
    "clinical_configs"          => crud_approve,
    "form_configurations"       => crud_approve,
    "staff"                     => crud_approve,
    "admin"                     => view_and_edit,
    "parent_portal"             => view_only
  }
  grant_permissions.call(roles_map[Role::Names::DIRECTOR], director_perms)

  # 3d. Clinical Program Director — Clinical leadership, assessment evaluation & IUP approvals
  program_director_perms = {
    "students"                  => crud_approve,
    "enrollments"               => crud_approve,
    "forms"                     => all_actions,
    "assessments"               => all_actions,
    "skills_assessments"        => all_actions,
    "behavior_assessments"      => all_actions,
    "preference_assessments"    => all_actions,
    "iups"                      => all_actions,
    "goals"                     => all_actions,
    "goal_domains"              => all_actions,
    "prompt_levels"             => view_and_edit,
    "sessions"                  => crud_approve,
    "trials"                    => view_only,
    "session_summaries"         => crud_approve,
    "behavior_incidents"        => all_actions,
    "abc_lists"                 => all_actions,
    "staff_members"             => view_and_edit,
    "staff_scheduling"          => crud_approve,
    "session_block_definitions" => view_and_edit,
    "session_schedule_configs"  => view_and_edit,
    "reports"                   => all_actions,
    "oversight"                 => all_actions,
    "audit_logs"                => view_only,
    "parent_communications"     => view_and_edit,
    "home_observations"         => view_only,
    "roles"                     => view_only,
    "clinical_configs"          => all_actions,
    "form_configurations"       => all_actions,
    "staff"                     => view_and_edit,
    "admin"                     => view_only,
    "parent_portal"             => view_only
  }
  grant_permissions.call(roles_map[Role::Names::PROGRAM_DIRECTOR], program_director_perms)

  # 3e. Therapy Coordinator — Operational scheduling, caseload routing, and therapist supervision
  coordinator_perms = {
    "students"                  => crud_approve,
    "enrollments"               => crud_approve,
    "forms"                     => view_and_edit,
    "assessments"               => crud_approve,
    "skills_assessments"        => crud_approve,
    "behavior_assessments"      => crud_approve,
    "preference_assessments"    => crud_approve,
    "iups"                      => crud_approve,
    "goals"                     => crud_approve,
    "goal_domains"              => view_only,
    "prompt_levels"             => view_only,
    "sessions"                  => all_actions,
    "trials"                    => all_actions,
    "session_summaries"         => all_actions,
    "behavior_incidents"        => all_actions,
    "abc_lists"                 => view_and_edit,
    "staff_members"             => view_and_edit,
    "staff_scheduling"          => all_actions,
    "session_block_definitions" => all_actions,
    "session_schedule_configs"  => all_actions,
    "reports"                   => all_actions,
    "oversight"                 => all_actions,
    "audit_logs"                => view_only,
    "parent_communications"     => all_actions,
    "home_observations"         => view_and_edit,
    "roles"                     => view_only,
    "clinical_configs"          => view_and_edit,
    "form_configurations"       => view_only,
    "staff"                     => all_actions,
    "admin"                     => view_only,
    "parent_portal"             => view_and_edit
  }
  grant_permissions.call(roles_map[Role::Names::THERAPY_COORDINATOR], coordinator_perms)

  # 3f. Teacher / One-to-One Clinician — Clinical session delivery, trial recording, ABC incident logging
  teacher_perms = {
    "students"                  => view_and_edit,
    "enrollments"               => view_only,
    "forms"                     => view_only,
    "assessments"               => %w[view create edit index show update],
    "skills_assessments"        => %w[view create edit index show update],
    "behavior_assessments"      => %w[view create edit index show update],
    "preference_assessments"    => %w[view create edit index show update],
    "iups"                      => view_only,
    "goals"                     => %w[view create edit index show update],
    "goal_domains"              => view_only,
    "prompt_levels"             => view_only,
    "sessions"                  => %w[view create edit index show update],
    "trials"                    => %w[view create edit index show update],
    "session_summaries"         => %w[view create edit index show update],
    "behavior_incidents"        => %w[view create edit index show update],
    "abc_lists"                 => view_only,
    "staff_members"             => view_only,
    "staff_scheduling"          => view_only,
    "session_block_definitions" => view_only,
    "session_schedule_configs"  => view_only,
    "reports"                   => view_only,
    "oversight"                 => view_only,
    "parent_communications"     => %w[view create edit index show update],
    "home_observations"         => view_only,
    "staff"                     => view_only,
    "parent_portal"             => view_only
  }
  grant_permissions.call(roles_map[Role::Names::TEACHER], teacher_perms)

  # 3g. Parent / Guardian — Child progress, home observations, and teacher communication
  parent_perms = {
    "students"                  => view_only,
    "iups"                      => view_only,
    "goals"                     => view_only,
    "sessions"                  => view_only,
    "session_summaries"         => view_only,
    "reports"                   => view_only,
    "parent_communications"     => %w[view create edit index show update],
    "home_observations"         => %w[view create edit index show update],
    "parent_portal"             => %w[view create edit index show update]
  }
  grant_permissions.call(roles_map[Role::Names::PARENT], parent_perms)

  RolePermission.insert_all!(role_perms_to_insert) if role_perms_to_insert.any?

  puts "    ✓ Role permissions granted across all 7 canonical roles."

  # ----------------------------------------------------------------------------
  # 4. Authentic Melue Staff Accounts & Profiles
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Authentic Melue Foundation Staff..."

  staff_seed_data = [
    {
      email:        "admin@melue.foundation",
      full_name:    "System Admin",
      staff_number: "ADM-001",
      staff_role:   "admin",
      user_role:    :system_admin,
      canonical:    Role::Names::SYSTEM_ADMIN,
      phone:        "+251 91 100 0001"
    },
    {
      email:        "institutional.admin@melue.foundation",
      full_name:    "Robel Ayana",
      staff_number: "ADM-002",
      staff_role:   "admin",
      user_role:    :institutional_admin,
      canonical:    Role::Names::INSTITUTIONAL_ADMIN,
      phone:        "+251 91 100 0002"
    },
    {
      email:        "director@melue.foundation",
      full_name:    "Lidiya Hailu",
      staff_number: "ADM-003",
      staff_role:   "admin",
      user_role:    :institutional_admin,
      canonical:    Role::Names::DIRECTOR,
      phone:        "+251 91 100 0003"
    },
    {
      email:        "program.director@melue.foundation",
      full_name:    "Tihut Girma",
      staff_number: "STF-001",
      staff_role:   "program_director",
      user_role:    :clinical_staff,
      canonical:    Role::Names::PROGRAM_DIRECTOR,
      phone:        "+251 91 100 0004"
    },
    {
      email:        "coordinator@melue.foundation",
      full_name:    "Hana Kebede",
      staff_number: "STF-002",
      staff_role:   "therapy_coordinator",
      user_role:    :clinical_staff,
      canonical:    Role::Names::THERAPY_COORDINATOR,
      phone:        "+251 91 100 0005"
    },
    {
      email:        "teacher1@melue.foundation",
      full_name:    "Mibret Zenebe",
      staff_number: "STF-003",
      staff_role:   "teacher",
      user_role:    :therapist,
      canonical:    Role::Names::TEACHER,
      phone:        "+251 91 100 0006"
    },
    {
      email:        "teacher2@melue.foundation",
      full_name:    "Tsion Koste",
      staff_number: "STF-004",
      staff_role:   "teacher",
      user_role:    :therapist,
      canonical:    Role::Names::TEACHER,
      phone:        "+251 91 100 0007"
    },
    {
      email:        "teacher3@melue.foundation",
      full_name:    "Dawit Bekele",
      staff_number: "STF-005",
      staff_role:   "teacher",
      user_role:    :therapist,
      canonical:    Role::Names::TEACHER,
      phone:        "+251 91 100 0008"
    }
  ]

  staff_seed_data.each do |stf|
    user = User.find_or_initialize_by(email: stf[:email])
    user.password_hash = hashed_password
    user.status        = :verified
    user.role          = stf[:user_role]
    user.save!

    staff = StaffMember.find_or_initialize_by(staff_number: stf[:staff_number])
    staff.user         = user
    staff.full_name    = stf[:full_name]
    staff.role         = stf[:staff_role]
    staff.phone        = stf[:phone]
    staff.discarded_at = nil
    staff.save!

    # Idempotent Role Assignment & UserRole synchronization
    target_role = roles_map[stf[:canonical]]
    user.assign_role(target_role)
    UserRole.find_or_create_by!(user: user, role: target_role)

    puts "    ✓ #{stf[:full_name].ljust(22)} [#{stf[:staff_number]}] -> #{stf[:email]} (#{stf[:canonical]})"
  end

  # ----------------------------------------------------------------------------
  # 5. Authentic Guardian Account (Parent of Adel)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Authentic Guardian/Parent Account..."

  parent_email = "parent@melue.foundation"
  parent_user = User.find_or_initialize_by(email: parent_email)
  parent_user.password_hash = hashed_password
  parent_user.status        = :verified
  parent_user.role          = :therapist # Default fallback enum value
  parent_user.save!

  parent_guardian = Guardian.find_or_initialize_by(user: parent_user)
  parent_guardian.full_name = "Almaz Girma"
  parent_guardian.phone     = "+251 91 123 4567"
  parent_guardian.save!

  parent_role = roles_map[Role::Names::PARENT]
  parent_user.assign_role(parent_role)
  UserRole.find_or_create_by!(user: parent_user, role: parent_role)

  puts "    ✓ #{parent_guardian.full_name.ljust(22)} [Parent of Adel] -> #{parent_email} (#{Role::Names::PARENT})"

  # ----------------------------------------------------------------------------
  # 6. Global UserRole & RoleAssignment Integrity Verification
  # ----------------------------------------------------------------------------
  User.find_each do |u|
    u.roles.each do |r|
      UserRole.find_or_create_by!(user: u, role: r)
    end
  end

  puts "\n--> Credential Verification Summary:"
  puts "    Total Users:         #{User.count}"
  puts "    Total Staff:         #{StaffMember.count}"
  puts "    Total Guardians:     #{Guardian.count}"
  puts "    Total Roles:         #{Role.count}"
  puts "    Total RolePerms:     #{RolePermission.count}"
  puts "    Default Password:    #{SEED_PASSWORD}"
  puts ("=" * 80) + "\n"
end
