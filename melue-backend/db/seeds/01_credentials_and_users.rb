# frozen_string_literal: true

require "bcrypt"

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File 1/5: db/seeds/01_credentials_and_users.rb
#
# Scope:
#   1. Core RBAC Roles (7 standard roles per FR-016 / System Architecture)
#   2. Complete Granular Permissions Matrix (Canonical + REST actions)
#   3. Role-Permission Assignments
#   4. Authentic Staff Accounts (Institutional Admin, Director One, PDirector One, etc.)
#   5. Authentic Guardian/Parent Account (Parent of Student A)
#   6. Role Assignments (RoleAssignment & UserRole synchronization)
# ==============================================================================

puts "\n" + ("=" * 80)
puts "  [SEED 01/05] CREDENTIALS, ROLES, RBAC PERMISSIONS & USERS"
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
  # 3. Role-Permission Mappings (Synchronized with RBAC Matrix)
  # ----------------------------------------------------------------------------
  puts "\n--> Mapping Permissions to Roles..."

  # Reset standard role permissions to ensure clean idempotent synchronization
  RolePermission.where(role_id: roles_map.values.map(&:id)).delete_all
  existing_role_perms = Set.new
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

  # 3a. System Administrator — Staff Account Management, Role Management, Permission Configuration (RBAC), System Audit Log
  sys_admin_perms = {
    "staff_members"       => all_actions,
    "roles"               => all_actions,
    "clinical_configs"    => all_actions,
    "audit_logs"          => all_actions,
    "admin"               => all_actions,
    "staff"               => all_actions
  }
  grant_permissions.call(roles_map[Role::Names::SYSTEM_ADMIN], sys_admin_perms)

  # 3b. Institutional Administrator — Schedule & Capacity Configuration, Form Builder, ABC Dropdown Lists, Trial Logging Format Config, Goal Bank / Domains, Staff Provisioning
  institutional_admin_perms = {
    "session_schedule_configs"  => crud_approve,
    "staff_scheduling"          => crud_approve,
    "form_configurations"       => crud_approve,
    "forms"                     => crud_approve,
    "abc_lists"                 => crud_approve,
    "behavior_incidents"        => crud_approve,
    "prompt_levels"             => crud_approve,
    "sessions"                  => crud_approve,
    "goal_domains"              => crud_approve,
    "goals"                     => crud_approve,
    "iups"                      => crud_approve,
    "clinical_configs"          => crud_approve,
    "staff"                     => crud_approve,
    "staff_members"             => crud_approve,
    "admin"                     => view_and_edit
  }
  grant_permissions.call(roles_map[Role::Names::INSTITUTIONAL_ADMIN], institutional_admin_perms)

  # 3c. Executive Director — Staff Scheduling & Capacity, Goal Mastery Approval, Parent Communication, Reports & Executive Oversight, Custom Report Builder
  director_perms = {
    "staff_scheduling"          => crud_approve,
    "session_schedule_configs"  => crud_approve,
    "goals"                     => crud_approve,
    "parent_communications"     => crud_approve,
    "parent_portal"             => crud_approve,
    "reports"                   => all_actions,
    "oversight"                 => all_actions,
    "staff"                     => crud_approve,
    "staff_members"             => view_and_edit
  }
  grant_permissions.call(roles_map[Role::Names::DIRECTOR], director_perms)

  # 3d. Clinical Program Director — Student Enrollment Wizard, Student Register & Roster List, IUP Creation & Goal Assignment, IUP Library Management, Assessment Review & Sign-Off, Assessment Summary Report, Student Caseload Management, Goal Bank, Reports & Executive Oversight
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
    "reports"                   => all_actions,
    "oversight"                 => all_actions,
    "clinical_configs"          => all_actions,
    "form_configurations"       => all_actions
  }
  grant_permissions.call(roles_map[Role::Names::PROGRAM_DIRECTOR], program_director_perms)

  # 3e. Therapy Coordinator — Live Session Monitoring, Session Summary Review, Student Register & Roster List, Student Enrollment Wizard, Staff Workload & Therapist Linking, Room Resource Scheduling, Parent Communication
  coordinator_perms = {
    "sessions"                  => all_actions,
    "trials"                    => all_actions,
    "session_summaries"         => all_actions,
    "students"                  => crud_approve,
    "enrollments"               => crud_approve,
    "staff_members"             => view_and_edit,
    "staff_scheduling"          => all_actions,
    "session_block_definitions" => all_actions,
    "parent_communications"     => all_actions,
    "parent_portal"             => all_actions,
    "staff"                     => all_actions
  }
  grant_permissions.call(roles_map[Role::Names::THERAPY_COORDINATOR], coordinator_perms)

  # 3f. Teacher / One-to-One Clinician — Session Data Collection, Assessment Dashboard, ABC Behavior Incident Log, Daily Session Notes, Parent Communication
  teacher_perms = {
    "sessions"                  => %w[view create edit index show update],
    "trials"                    => %w[view create edit index show update],
    "session_summaries"         => %w[view create edit index show update],
    "assessments"               => %w[view create edit index show update],
    "skills_assessments"        => %w[view create edit index show update],
    "behavior_assessments"      => %w[view create edit index show update],
    "preference_assessments"    => %w[view create edit index show update],
    "behavior_incidents"        => %w[view create edit index show update],
    "abc_lists"                 => %w[view index show],
    "parent_communications"     => %w[view create edit index show update],
    "parent_portal"             => %w[view index show]
  }
  grant_permissions.call(roles_map[Role::Names::TEACHER], teacher_perms)

  # 3g. Parent / Guardian — Child Progress Tracker, Home Observation Log, Parent Communication (Messages)
  parent_perms = {
    "students"                  => view_only,
    "iups"                      => view_only,
    "goals"                     => view_only,
    "sessions"                  => view_only,
    "reports"                   => view_only,
    "home_observations"         => %w[view create edit index show update],
    "parent_communications"     => %w[view create edit index show update],
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
      full_name:    "Institutional Admin",
      staff_number: "ADM-002",
      staff_role:   "admin",
      user_role:    :institutional_admin,
      canonical:    Role::Names::INSTITUTIONAL_ADMIN,
      phone:        "+251 91 100 0002"
    },
    {
      email:        "director@melue.foundation",
      full_name:    "Director One",
      staff_number: "ADM-003",
      staff_role:   "admin",
      user_role:    :institutional_admin,
      canonical:    Role::Names::DIRECTOR,
      phone:        "+251 91 100 0003"
    },
    {
      email:        "program.director@melue.foundation",
      full_name:    "PDirector One",
      staff_number: "STF-001",
      staff_role:   "program_director",
      user_role:    :clinical_staff,
      canonical:    Role::Names::PROGRAM_DIRECTOR,
      phone:        "+251 91 100 0004"
    },
    {
      email:        "coordinator@melue.foundation",
      full_name:    "Coordinator One",
      staff_number: "STF-002",
      staff_role:   "therapy_coordinator",
      user_role:    :clinical_staff,
      canonical:    Role::Names::THERAPY_COORDINATOR,
      phone:        "+251 91 100 0005"
    },
    {
      email:        "teacher1@melue.foundation",
      full_name:    "Teacher One",
      staff_number: "STF-003",
      staff_role:   "teacher",
      user_role:    :therapist,
      canonical:    Role::Names::TEACHER,
      phone:        "+251 91 100 0006"
    },
    {
      email:        "teacher2@melue.foundation",
      full_name:    "Teacher Two",
      staff_number: "STF-004",
      staff_role:   "teacher",
      user_role:    :therapist,
      canonical:    Role::Names::TEACHER,
      phone:        "+251 91 100 0007"
    },
    {
      email:        "teacher3@melue.foundation",
      full_name:    "Teacher Three",
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
  # 5. Authentic Guardian Account (Parent of Student A)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Authentic Guardian/Parent Account..."

  parent_email = "parent@melue.foundation"
  parent_user = User.find_or_initialize_by(email: parent_email)
  parent_user.password_hash = hashed_password
  parent_user.status        = :verified
  parent_user.role          = :therapist # Default fallback enum value
  parent_user.save!

  parent_guardian = Guardian.find_or_initialize_by(user: parent_user)
  parent_guardian.full_name = "Parent One"
  parent_guardian.phone     = "+251 91 123 4567"
  parent_guardian.save!

  parent_role = roles_map[Role::Names::PARENT]
  parent_user.assign_role(parent_role)
  UserRole.find_or_create_by!(user: parent_user, role: parent_role)

  puts "    ✓ #{parent_guardian.full_name.ljust(22)} [Parent of Student A] -> #{parent_email} (#{Role::Names::PARENT})"

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
