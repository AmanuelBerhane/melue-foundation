# frozen_string_literal: true

# Seeds for local development and CI.
# Generates a self-contained, realistic environment covering all 7 roles,
# all student pipeline states, and a complete goal bank.
# All operations use find_or_create_by! to keep seeds idempotent.

puts "Seeding..."

SEED_PASSWORD = "Password123!"

# ==============================================================================
# 1. Prompt Levels (FR-094 — configurable, not hardcoded)
# ==============================================================================
prompt_levels = [
  { label: "FP", color: "#EF4444", display_order: 1 }, # Full Prompt
  { label: "PP", color: "#F97316", display_order: 2 }, # Partial Prompt
  { label: "G",  color: "#EAB308", display_order: 3 }, # Gesture
  { label: "+",  color: "#22C55E", display_order: 4 }  # Independent
]

prompt_levels.each do |attrs|
  PromptLevel.find_or_create_by!(label: attrs[:label]) do |pl|
    pl.color         = attrs[:color]
    pl.display_order = attrs[:display_order]
    pl.is_active     = true
  end
end

puts "  ✓ #{PromptLevel.count} prompt levels"

# ==============================================================================
# 2. Therapy Stations & Rooms (Rooms 1A–1D, 2A–2D)
# ==============================================================================
station1 = TherapyStation.find_or_create_by!(name: "Station 1")
station2 = TherapyStation.find_or_create_by!(name: "Station 2")

[
  [ station1, "Room 1A" ],
  [ station1, "Room 1B" ],
  [ station1, "Room 1C" ],
  [ station1, "Room 1D" ],
  [ station2, "Room 2A" ],
  [ station2, "Room 2B" ],
  [ station2, "Room 2C" ],
  [ station2, "Room 2D" ]
].each do |station, room_name|
  TherapyRoom.find_or_create_by!(therapy_station: station, name: room_name)
end

puts "  ✓ #{TherapyStation.count} stations, #{TherapyRoom.count} rooms"

# ==============================================================================
# 3. Session Block Definitions
# ==============================================================================
blocks_seed = [
  { name: "Morning Block A",   start_time: "08:00", end_time: "09:30", round: "morning"   },
  { name: "Morning Block B",   start_time: "09:45", end_time: "11:15", round: "morning"   },
  { name: "Afternoon Block A", start_time: "12:30", end_time: "14:00", round: "afternoon" },
  { name: "Afternoon Block B", start_time: "14:15", end_time: "15:45", round: "afternoon" }
]

blocks_seed.each do |attrs|
  SessionBlockDefinition.find_or_create_by!(name: attrs[:name]) do |b|
    b.start_time = attrs[:start_time]
    b.end_time   = attrs[:end_time]
    b.round      = attrs[:round]
    b.is_active  = true
  end
end

puts "  ✓ #{SessionBlockDefinition.count} session blocks"

# ==============================================================================
# 4. Goal Bank — 5 canonical domains with standard + task analysis goals
#    Domains: Communication | Motor | Social | Self-Help | Cognition
# ==============================================================================
domains_seed = [
  { name: "Communication", display_order: 1 },
  { name: "Motor",         display_order: 2 },
  { name: "Social",        display_order: 3 },
  { name: "Self-Help",     display_order: 4 },
  { name: "Cognition",     display_order: 5 }
]

domain_records = domains_seed.each_with_object({}) do |attrs, hash|
  hash[attrs[:name]] = GoalDomain.find_or_create_by!(name: attrs[:name]) do |d|
    d.display_order = attrs[:display_order]
    d.is_active     = true
  end
end

goals_seed = [
  # ── Communication ──────────────────────────────────────────────────────────
  { domain: "Communication", name: "Request preferred items using words",          type: "standard"      },
  { domain: "Communication", name: "Follow two-step verbal instructions",          type: "standard"      },
  { domain: "Communication", name: "Answer simple 'what' questions",               type: "standard"      },
  { domain: "Communication", name: "Use PECS to request preferred items",          type: "standard"      },
  { domain: "Communication", name: "Requesting Sequence (verbal)",                 type: "task_analysis" },

  # ── Motor ──────────────────────────────────────────────────────────────────
  { domain: "Motor", name: "Maintain pencil grip for 3 minutes",                   type: "standard"      },
  { domain: "Motor", name: "Cut along a straight line with scissors",              type: "standard"      },
  { domain: "Motor", name: "Stack 6 blocks independently",                         type: "standard"      },
  { domain: "Motor", name: "Writing First Name",                                   type: "task_analysis" },

  # ── Social ─────────────────────────────────────────────────────────────────
  { domain: "Social", name: "Initiate greeting with peers",                        type: "standard"      },
  { domain: "Social", name: "Take turns in structured play",                       type: "standard"      },
  { domain: "Social", name: "Make eye contact during conversation",                type: "standard"      },
  { domain: "Social", name: "Share materials with a peer",                         type: "standard"      },

  # ── Self-Help ──────────────────────────────────────────────────────────────
  { domain: "Self-Help", name: "Use a napkin when eating",                         type: "standard"      },
  { domain: "Self-Help", name: "Drink from an open cup independently",             type: "standard"      },
  { domain: "Self-Help", name: "Washing Hands",                                    type: "task_analysis" },
  { domain: "Self-Help", name: "Toileting - Urination",                            type: "task_analysis" },
  { domain: "Self-Help", name: "Toileting - Request",                              type: "task_analysis" },
  { domain: "Self-Help", name: "Dressing - Shoes",                                 type: "task_analysis" },
  { domain: "Self-Help", name: "Dressing - Pants",                                 type: "task_analysis" },
  { domain: "Self-Help", name: "Pack school bag",                                  type: "task_analysis" },

  # ── Cognition ──────────────────────────────────────────────────────────────
  { domain: "Cognition", name: "Match identical objects",                          type: "standard"      },
  { domain: "Cognition", name: "Sort objects by color",                            type: "standard"      },
  { domain: "Cognition", name: "Identify letters A-Z by name",                    type: "standard"      },
  { domain: "Cognition", name: "Count objects 1-10 with one-to-one correspondence", type: "standard"    },
  { domain: "Cognition", name: "Identify basic shapes",                            type: "standard"      }
]

goals_seed.each do |attrs|
  Goal.find_or_create_by!(name: attrs[:name], goal_domain: domain_records[attrs[:domain]]) do |g|
    g.goal_type = attrs[:type]
    g.is_active = true
  end
end

puts "  ✓ #{GoalDomain.count} goal domains, #{Goal.count} goals"

# ==============================================================================
# 5. Staff Users & Profiles — one account per role (password: Password123!)
# ==============================================================================

# ── System Administrator ──────────────────────────────────────────────────────
admin_user = User.find_or_create_by!(email: "admin@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
  u.role          = :system_admin
end
admin_user.update!(role: :system_admin) unless admin_user.system_admin?

admin_staff = StaffMember.find_or_create_by!(user: admin_user) do |s|
  s.full_name    = "System Admin"
  s.staff_number = "ADM-001"
  s.role         = "admin"
end
admin_staff.update!(role: "admin") unless admin_staff.role_admin?

# ── Institutional Administrator ───────────────────────────────────────────────
inst_admin_user = User.find_or_create_by!(email: "institutional.admin@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
  u.role          = :institutional_admin
end
inst_admin_user.update!(role: :institutional_admin) unless inst_admin_user.institutional_admin?

inst_admin_staff = StaffMember.find_or_create_by!(user: inst_admin_user) do |s|
  s.full_name    = "Robel Ayana"
  s.staff_number = "ADM-002"
  s.role         = "admin"
end
inst_admin_staff.update!(role: "admin") unless inst_admin_staff.role_admin?

# ── Director ──────────────────────────────────────────────────────────────────
# StaffMember has no 'director' enum — uses 'admin'; RBAC role drives routing.
director_user = User.find_or_create_by!(email: "director@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
  u.role          = :institutional_admin
end

director_staff = StaffMember.find_or_create_by!(user: director_user) do |s|
  s.full_name    = "Lidiya Hailu"
  s.staff_number = "ADM-003"
  s.role         = "admin"
end
director_staff.update!(role: "admin") unless director_staff.role_admin?

# ── Program Director ──────────────────────────────────────────────────────────
program_director_user = User.find_or_create_by!(email: "program.director@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

program_director_staff = StaffMember.find_or_create_by!(user: program_director_user) do |s|
  s.full_name    = "Bereket Mengistu"
  s.staff_number = "STF-001"
  s.role         = "program_director"
end
program_director_staff.update!(role: "program_director") unless program_director_staff.role_program_director?

# ── Therapy Coordinator ───────────────────────────────────────────────────────
coordinator_user = User.find_or_create_by!(email: "coordinator@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

coordinator_staff = StaffMember.find_or_create_by!(user: coordinator_user) do |s|
  s.full_name    = "Hana Kebede"
  s.staff_number = "STF-002"
  s.role         = "therapy_coordinator"
end
coordinator_staff.update!(role: "therapy_coordinator") unless coordinator_staff.role_therapy_coordinator?

# ── Teachers ──────────────────────────────────────────────────────────────────
teacher1_user = User.find_or_create_by!(email: "teacher1@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

teacher2_user = User.find_or_create_by!(email: "teacher2@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

teacher3_user = User.find_or_create_by!(email: "teacher3@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

teacher1 = StaffMember.find_or_create_by!(user: teacher1_user) do |s|
  s.full_name    = "Abeba Tadesse"
  s.staff_number = "STF-003"
  s.role         = "teacher"
end
teacher1.update!(role: "teacher") unless teacher1.role_teacher?

teacher2 = StaffMember.find_or_create_by!(user: teacher2_user) do |s|
  s.full_name    = "Dawit Bekele"
  s.staff_number = "STF-004"
  s.role         = "teacher"
end
teacher2.update!(role: "teacher") unless teacher2.role_teacher?

teacher3 = StaffMember.find_or_create_by!(user: teacher3_user) do |s|
  s.full_name    = "Selam Tesfaye"
  s.staff_number = "STF-005"
  s.role         = "teacher"
end
teacher3.update!(role: "teacher") unless teacher3.role_teacher?

puts "  ✓ #{StaffMember.count} staff members"

# ── Parent User & Guardian ────────────────────────────────────────────────────
# Parents use Guardian records; RBAC role drives portal routing.
parent_user = User.find_or_create_by!(email: "parent@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create(SEED_PASSWORD)
  u.status        = 2
end

parent_guardian = Guardian.find_or_create_by!(full_name: "Almaz Girma") do |g|
  g.user  = parent_user
  g.phone = "555-9900"
end
parent_guardian.update!(user: parent_user) if parent_guardian.user.nil?

# ==============================================================================
# 6. RBAC: Roles & Permissions
# ==============================================================================
role_definitions = {
  Role::Names::SYSTEM_ADMIN        => { critical: true,  desc: "Full system access and security administration" },
  Role::Names::INSTITUTIONAL_ADMIN => { critical: true,  desc: "Institutional administration and facility configuration" },
  Role::Names::DIRECTOR            => { critical: false, desc: "Executive oversight, compliance and reporting" },
  Role::Names::PROGRAM_DIRECTOR    => { critical: false, desc: "Clinical management, assessment and IUP approval" },
  Role::Names::THERAPY_COORDINATOR => { critical: false, desc: "Operational therapy coordination, scheduling and review" },
  Role::Names::TEACHER             => { critical: false, desc: "Standard clinical therapy provider" },
  Role::Names::PARENT              => { critical: false, desc: "Parent portal student progress and communication access" }
}

roles_map = {}
role_definitions.each do |name, meta|
  roles_map[name] = Role.find_or_create_by!(name: name) do |r|
    r.is_system_critical = meta[:critical]
    r.is_active          = true
    r.description        = meta[:desc]
  end
end

admin_role            = roles_map[Role::Names::SYSTEM_ADMIN]
inst_admin_role       = roles_map[Role::Names::INSTITUTIONAL_ADMIN]
director_role         = roles_map[Role::Names::DIRECTOR]
program_director_role = roles_map[Role::Names::PROGRAM_DIRECTOR]
coordinator_role      = roles_map[Role::Names::THERAPY_COORDINATOR]
teacher_role          = roles_map[Role::Names::TEACHER]
parent_role           = roles_map[Role::Names::PARENT]

# Comprehensive permissions catalogue
resources = %w[roles staff_members students assessments iups sessions goals reports audit_logs forms behavior_incidents]
actions   = %w[index show create update destroy manage]

permission_catalog = {}
resources.each do |res|
  actions.each do |act|
    permission_catalog["#{res}:#{act}"] = Permission.find_or_create_by!(resource: res, action: act)
  end
end

grant_permissions = lambda do |role, res_actions_hash|
  res_actions_hash.each do |res, acts|
    acts.each do |act|
      perm = permission_catalog["#{res}:#{act}"]
      RolePermission.find_or_create_by!(role: role, permission: perm) if perm
    end
  end
end

# System Admin & Institutional Admin: Full access
all_permissions = resources.each_with_object({}) { |r, h| h[r] = actions }
grant_permissions.call(admin_role, all_permissions)
grant_permissions.call(inst_admin_role, all_permissions)

# Director & Program Director: Clinical & operational oversight
director_perms = {
  "staff_members"      => %w[index show create update manage],
  "students"           => %w[index show create update manage],
  "assessments"        => %w[index show create update manage],
  "iups"               => %w[index show create update manage],
  "sessions"           => %w[index show create update manage],
  "goals"              => %w[index show create update manage],
  "reports"            => %w[index show create update manage],
  "behavior_incidents" => %w[index show create update manage],
  "forms"              => %w[index show]
}
grant_permissions.call(director_role, director_perms)
grant_permissions.call(program_director_role, director_perms)

# Therapy Coordinator: Scheduling, review and student coordination
coord_perms = {
  "staff_members"      => %w[index show update],
  "students"           => %w[index show create update],
  "assessments"        => %w[index show create update],
  "iups"               => %w[index show create update],
  "sessions"           => %w[index show create update manage],
  "goals"              => %w[index show create update],
  "reports"            => %w[index show],
  "behavior_incidents" => %w[index show create update]
}
grant_permissions.call(coordinator_role, coord_perms)

# Teacher: Clinical therapy execution and logging
teacher_perms = {
  "students"           => %w[index show update],
  "assessments"        => %w[index show create update],
  "iups"               => %w[index show],
  "sessions"           => %w[index show create update],
  "goals"              => %w[index show create update],
  "behavior_incidents" => %w[index show create update]
}
grant_permissions.call(teacher_role, teacher_perms)

# Parent: Guardian portal visibility
parent_perms = {
  "students" => %w[index show],
  "iups"     => %w[index show],
  "reports"  => %w[index show]
}
grant_permissions.call(parent_role, parent_perms)

# UserRole records (required for current_user.has_permission?)
UserRole.find_or_create_by!(user: admin_user,            role: admin_role)
UserRole.find_or_create_by!(user: inst_admin_user,       role: inst_admin_role)
UserRole.find_or_create_by!(user: director_user,         role: director_role)
UserRole.find_or_create_by!(user: program_director_user, role: program_director_role)
UserRole.find_or_create_by!(user: coordinator_user,      role: coordinator_role)
[ teacher1_user, teacher2_user, teacher3_user ].each do |u|
  UserRole.find_or_create_by!(user: u, role: teacher_role)
end
UserRole.find_or_create_by!(user: parent_user, role: parent_role)

# Role assignments (idempotent)
[ teacher1_user, teacher2_user, teacher3_user ].each { |u| u.assign_role(Role::Names::TEACHER) }
admin_user.assign_role(Role::Names::SYSTEM_ADMIN)
inst_admin_user.assign_role(Role::Names::INSTITUTIONAL_ADMIN)
coordinator_user.assign_role(Role::Names::THERAPY_COORDINATOR)
program_director_user.assign_role(Role::Names::PROGRAM_DIRECTOR)
director_user.assign_role(Role::Names::DIRECTOR)
parent_user.assign_role(Role::Names::PARENT)

puts "  ✓ #{Role.count} roles, #{Permission.count} permissions, #{RolePermission.count} role permissions, #{UserRole.count} user roles"

# ==============================================================================
# 7. Students — 10 across all pipeline states
#
#   2  in_assessment   — ready for ABLLS scoring
#   2  ready_for_iup   — assessments complete, plan creation pending
#   4  active_therapy  — assigned to stations/rooms/blocks, 2 active goals each
#   2  completed-sess. — active_therapy with completed session history;
#                        ready for mastery checks and director reports
# ==============================================================================

# ── 2 "In Assessment" ─────────────────────────────────────────────────────────
student_a1 = Student.find_or_create_by!(first_name: "Amir", last_name: "Hassan") do |s|
  s.date_of_birth  = "2019-07-22"
  s.therapy_group  = "basic"
  s.program_type   = "regular"
  s.status         = "in_assessment"
  s.guardian_name  = "Fatuma Hassan"
  s.guardian_phone = "555-2001"
end

student_a2 = Student.find_or_create_by!(first_name: "Tigist", last_name: "Bekele") do |s|
  s.date_of_birth  = "2018-11-14"
  s.therapy_group  = "basic"
  s.program_type   = "pulled_out"
  s.status         = "in_assessment"
  s.guardian_name  = "Almaz Bekele"
  s.guardian_phone = "555-2002"
end

# ── 2 "Ready for IUP" ─────────────────────────────────────────────────────────
student_b1 = Student.find_or_create_by!(first_name: "Saron", last_name: "Tekle") do |s|
  s.date_of_birth  = "2017-03-18"
  s.therapy_group  = "basic"
  s.program_type   = "regular"
  s.status         = "ready_for_iup"
  s.guardian_name  = "Hiwot Tekle"
  s.guardian_phone = "555-2003"
  s.diagnosis      = "ASD Level 1"
end

student_b2 = Student.find_or_create_by!(first_name: "Biniam", last_name: "Hailu") do |s|
  s.date_of_birth  = "2013-09-05"
  s.therapy_group  = "functional_living"
  s.program_type   = "regular"
  s.status         = "ready_for_iup"
  s.guardian_name  = "Mekdes Hailu"
  s.guardian_phone = "555-2004"
  s.diagnosis      = "ASD Level 2"
end

# ── 4 "Active Therapy" (2 goals each, assigned to rooms + blocks) ─────────────
student_c1 = Student.find_or_create_by!(first_name: "Yonas", last_name: "Girma") do |s|
  s.date_of_birth  = "2018-04-12"
  s.therapy_group  = "basic"
  s.program_type   = "regular"
  s.status         = "active_therapy"
  s.guardian_name  = "Girma Parent"
  s.guardian_phone = "555-1234"
  s.diagnosis      = "ASD Level 2"
end

student_c2 = Student.find_or_create_by!(first_name: "Meron", last_name: "Haile") do |s|
  s.date_of_birth  = "2017-09-05"
  s.therapy_group  = "basic"
  s.program_type   = "regular"
  s.status         = "active_therapy"
  s.guardian_name  = "Haile Parent"
  s.guardian_phone = "555-5678"
  s.diagnosis      = "ASD Level 1"
end

student_c3 = Student.find_or_create_by!(first_name: "Abel", last_name: "Tadesse") do |s|
  s.date_of_birth  = "2019-02-20"
  s.therapy_group  = "basic"
  s.program_type   = "pulled_out"
  s.status         = "active_therapy"
  s.guardian_name  = "Tadesse Parent"
  s.guardian_phone = "555-1001"
  s.diagnosis      = "ASD Level 2"
end

student_c4 = Student.find_or_create_by!(first_name: "Liya", last_name: "Belay") do |s|
  s.date_of_birth  = "2016-11-30"
  s.therapy_group  = "basic"
  s.program_type   = "regular"
  s.status         = "active_therapy"
  s.guardian_name  = "Belay Parent"
  s.guardian_phone = "555-1002"
  s.diagnosis      = "ASD Level 1"
end

# ── 2 "Completed Sessions" (active_therapy + historical assignments) ──────────
student_d1 = Student.find_or_create_by!(first_name: "Natnael", last_name: "Worku") do |s|
  s.date_of_birth  = "2013-06-15"
  s.therapy_group  = "functional_living"
  s.program_type   = "regular"
  s.status         = "active_therapy"
  s.guardian_name  = "Worku Parent"
  s.guardian_phone = "555-1003"
  s.diagnosis      = "ASD Level 3"
end

student_d2 = Student.find_or_create_by!(first_name: "Hiwot", last_name: "Alemu") do |s|
  s.date_of_birth  = "2014-08-08"
  s.therapy_group  = "functional_living"
  s.program_type   = "pulled_out"
  s.status         = "active_therapy"
  s.guardian_name  = "Alemu Parent"
  s.guardian_phone = "555-1004"
  s.diagnosis      = "ASD Level 2"
end

puts "  ✓ #{Student.count} students"

# ==============================================================================
# 8. IUPs & Student Goals
#    Active-therapy students (c1–c4, d1–d2) each get 2 active goals.
# ==============================================================================
request_goal   = Goal.find_by!(name: "Request preferred items using words")
greeting_goal  = Goal.find_by!(name: "Initiate greeting with peers")
motor_goal     = Goal.find_by!(name: "Maintain pencil grip for 3 minutes")
eye_contact    = Goal.find_by!(name: "Make eye contact during conversation")
washing_goal   = Goal.find_by!(name: "Washing Hands")
turns_goal     = Goal.find_by!(name: "Take turns in structured play")
pecs_goal      = Goal.find_by!(name: "Use PECS to request preferred items")
matching_goal  = Goal.find_by!(name: "Match identical objects")

# IUPs
iup_c1 = Iup.find_or_create_by!(student: student_c1, status: "active") { |i| i.finalized_on = Date.current - 45.days }
iup_c2 = Iup.find_or_create_by!(student: student_c2, status: "active") { |i| i.finalized_on = Date.current - 38.days }
iup_c3 = Iup.find_or_create_by!(student: student_c3, status: "active") { |i| i.finalized_on = Date.current - 30.days }
iup_c4 = Iup.find_or_create_by!(student: student_c4, status: "active") { |i| i.finalized_on = Date.current - 25.days }
iup_d1 = Iup.find_or_create_by!(student: student_d1, status: "active") { |i| i.finalized_on = Date.current - 60.days }
iup_d2 = Iup.find_or_create_by!(student: student_d2, status: "active") { |i| i.finalized_on = Date.current - 55.days }

# student_c1 — Communication + Social (Station 1)
StudentGoal.find_or_create_by!(iup: iup_c1, goal: request_goal, student: student_c1) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 45.0
end
StudentGoal.find_or_create_by!(iup: iup_c1, goal: greeting_goal, student: student_c1) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 30.0
end

# student_c2 — Social + Motor (Station 1)
StudentGoal.find_or_create_by!(iup: iup_c2, goal: turns_goal, student: student_c2) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 55.0
end
StudentGoal.find_or_create_by!(iup: iup_c2, goal: motor_goal, student: student_c2) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 20.0
end

# student_c3 — Communication + Cognition (Station 1 / Station 2)
StudentGoal.find_or_create_by!(iup: iup_c3, goal: pecs_goal, student: student_c3) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 10.0
end
StudentGoal.find_or_create_by!(iup: iup_c3, goal: matching_goal, student: student_c3) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 25.0
end

# student_c4 — Social + Motor (Station 1 / Station 2)
StudentGoal.find_or_create_by!(iup: iup_c4, goal: greeting_goal, student: student_c4) do |sg|
  sg.therapy_station  = station1; sg.status = "active"; sg.progress_percent = 60.0
end
StudentGoal.find_or_create_by!(iup: iup_c4, goal: motor_goal, student: student_c4) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 35.0
end

# student_d1 — Communication + Self-Help (Station 2) — completed-session student
StudentGoal.find_or_create_by!(iup: iup_d1, goal: request_goal, student: student_d1) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 70.0
end
StudentGoal.find_or_create_by!(iup: iup_d1, goal: washing_goal, student: student_d1) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 80.0
end

# student_d2 — Social + Cognition (Station 2) — completed-session student
StudentGoal.find_or_create_by!(iup: iup_d2, goal: eye_contact, student: student_d2) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 65.0
end
StudentGoal.find_or_create_by!(iup: iup_d2, goal: matching_goal, student: student_d2) do |sg|
  sg.therapy_station  = station2; sg.status = "active"; sg.progress_percent = 50.0
end

puts "  ✓ #{Iup.count} IUPs, #{StudentGoal.count} student goals"

# ==============================================================================
# 8.5 ABC Dropdown Options
# ==============================================================================
abc_options = [
  { category: "antecedent", label: "Denied access to preferred item", display_order: 1 },
  { category: "antecedent", label: "Transition between activities",   display_order: 2 },
  { category: "antecedent", label: "Task demand presented",           display_order: 3 },
  { category: "antecedent", label: "Other",                          display_order: 99, is_other: true },

  { category: "behavior",   label: "Hitting",                        display_order: 1 },
  { category: "behavior",   label: "Screaming",                      display_order: 2 },
  { category: "behavior",   label: "Property destruction",           display_order: 3 },
  { category: "behavior",   label: "Other",                          display_order: 99, is_other: true },

  { category: "consequence", label: "Removed from area",             display_order: 1 },
  { category: "consequence", label: "Given break",                   display_order: 2 },
  { category: "consequence", label: "Redirected to task",            display_order: 3 },
  { category: "consequence", label: "Other",                         display_order: 99, is_other: true }
]

abc_options.each do |attrs|
  AbcDropdownOption.find_or_create_by!(category: attrs[:category], label: attrs[:label]) do |opt|
    opt.display_order = attrs[:display_order]
    opt.is_active     = true
    opt.is_other      = attrs[:is_other] || false
  end
end

puts "  ✓ #{AbcDropdownOption.count} ABC dropdown options"

# ==============================================================================
# 8.6 Form Configurations
# ==============================================================================
form_configs = [
  {
    form_type: "enrollment",
    form_name: "Student Enrollment Form",
    revision_number: 1,
    organization_name: "Default Organization",
    field_schema: { "fields" => [] }
  },
  {
    form_type: "iup",
    form_name: "Individualized Plan (IUP)",
    revision_number: 1,
    organization_name: "Default Organization",
    is_default: true,
    field_schema: { "fields" => [] }
  },
  {
    form_type: "ablls",
    form_name: "ABLLS Assessment",
    revision_number: 1,
    organization_name: "Default Organization",
    field_schema: { "fields" => [] }
  }
]

form_configs.each do |attrs|
  FormConfiguration.find_or_create_by!(form_type: attrs[:form_type]) do |fc|
    fc.form_name          = attrs[:form_name]
    fc.revision_number    = attrs[:revision_number]
    fc.organization_name  = attrs[:organization_name]
    fc.is_default         = attrs[:is_default] || false
    fc.field_schema       = attrs[:field_schema]
  end
end

puts "  ✓ #{FormConfiguration.count} form configurations"

# ==============================================================================
# 8.7 Session Schedule Configuration
# ==============================================================================
SessionScheduleConfig.instance

puts "  ✓ Session schedule configuration initialized"

# ==============================================================================
# 9. Teacher-Student Assignments — today's schedule + completed history
# ==============================================================================
block_a  = SessionBlockDefinition.find_by!(name: "Morning Block A")
block_b  = SessionBlockDefinition.find_by!(name: "Morning Block B")
block_c  = SessionBlockDefinition.find_by!(name: "Afternoon Block A")

room_1a  = TherapyRoom.find_by!(name: "Room 1A")
room_1b  = TherapyRoom.find_by!(name: "Room 1B")
room_2a  = TherapyRoom.find_by!(name: "Room 2A")

# teacher1 → student_c1 & student_c2 | Morning Block A | Station 1 | Room 1A
[ student_c1, student_c2 ].each do |student|
  TeacherStudentAssignment.find_or_create_by!(
    teacher: teacher1, student: student,
    session_block_definition: block_a, scheduled_date: Date.current
  ) do |a|
    a.therapy_station = station1
    a.therapy_room    = room_1a
    a.status          = "scheduled"
  end
end

# teacher2 → student_c3 & student_c4 | Morning Block B | Station 1 | Room 1B
[ student_c3, student_c4 ].each do |student|
  TeacherStudentAssignment.find_or_create_by!(
    teacher: teacher2, student: student,
    session_block_definition: block_b, scheduled_date: Date.current
  ) do |a|
    a.therapy_station = station1
    a.therapy_room    = room_1b
    a.status          = "scheduled"
  end
end

# teacher3 → student_d1 & student_d2 | Afternoon Block A | Station 2 | Room 2A
# Today's assignment + 5-day completed history for mastery checks / director reports
[ student_d1, student_d2 ].each do |student|
  TeacherStudentAssignment.find_or_create_by!(
    teacher: teacher3, student: student,
    session_block_definition: block_c, scheduled_date: Date.current
  ) do |a|
    a.therapy_station = station2
    a.therapy_room    = room_2a
    a.status          = "scheduled"
  end

  # Historical completed sessions (last 5 school days)
  (1..5).each do |days_ago|
    TeacherStudentAssignment.find_or_create_by!(
      teacher: teacher3, student: student,
      session_block_definition: block_c, scheduled_date: Date.current - days_ago.days
    ) do |a|
      a.therapy_station = station2
      a.therapy_room    = room_2a
      a.status          = "completed"
    end
  end
end

puts "  ✓ #{TeacherStudentAssignment.count} assignments (#{TeacherStudentAssignment.for_today.count} for today)"

# ==============================================================================
# 10. Parent Relationships (StudentGuardian) — for parent portal testing
# ==============================================================================
# Link parent_guardian to two active-therapy students
StudentGuardian.find_or_create_by!(guardian: parent_guardian, student: student_c1) do |sg|
  sg.relationship       = "Mother"
  sg.is_primary_contact = true
end

StudentGuardian.find_or_create_by!(guardian: parent_guardian, student: student_d1) do |sg|
  sg.relationship       = "Mother"
  sg.is_primary_contact = false
end

puts "  ✓ #{StudentGuardian.count} guardian-student links"

# ==============================================================================
# 11. Task Analysis Step Templates (aligned to new goal bank)
# ==============================================================================
puts "Seeding Task Analysis Step Templates..."

task_analysis_steps = {
  # Self-Help
  "Washing Hands" => [
    "Turn on water", "Wet hands", "Apply soap",
    "Lather for 20 seconds", "Rinse hands", "Turn off water", "Dry hands"
  ],
  "Toileting - Urination" => [
    "Initiate toileting", "Go to toilet", "Pull down pants",
    "Sit / stand at toilet", "Urinate", "Wipe", "Pull up pants"
  ],
  "Toileting - Request" => [
    "Initiate request", "Use verbal / sign / device", "Wait for acknowledgment"
  ],
  "Dressing - Shoes" => [
    "Pick up shoe", "Put foot in shoe", "Fasten / close shoe"
  ],
  "Dressing - Pants" => [
    "Pick up pants", "Step into pants", "Pull pants up", "Fasten (button / zip)"
  ],
  "Pack school bag" => [
    "Open bag", "Place water bottle inside", "Place lunch box inside",
    "Place books / folders inside", "Zip bag closed", "Lift and carry bag"
  ],
  # Communication
  "Requesting Sequence (verbal)" => [
    "Orient to communicative partner",
    "Vocalize or sign request",
    "Wait for response (3 seconds)",
    "Accept item or re-request"
  ],
  # Motor
  "Writing First Name" => [
    "Hold pencil with correct grip",
    "Trace first letter from model",
    "Write first letter independently",
    "Trace remaining letters",
    "Write remaining letters independently",
    "Review completed name"
  ]
}

task_analysis_steps.each do |goal_name, steps|
  domain_name =
    case goal_name
    when /Washing|Toileting|Dressing|Pack/ then "Self-Help"
    when /Requesting/                       then "Communication"
    when /Writing/                          then "Motor"
    end

  goal = Goal.find_or_create_by!(name: goal_name, goal_domain: domain_records[domain_name]) do |g|
    g.goal_type = "task_analysis"
    g.is_active = true
  end
  goal.update!(goal_type: "task_analysis") unless goal.goal_type == "task_analysis"

  steps.each_with_index do |step_name, index|
    goal.task_analysis_step_templates.find_or_create_by!(step_number: index + 1) do |t|
      t.name = step_name
    end
  end

  puts "  ✓ #{steps.size} steps for '#{goal_name}'"
end

# Instantiate StudentGoalStep records for every active task_analysis StudentGoal
StudentGoal.where(status: %w[active in_progress]).find_each do |student_goal|
  next unless student_goal.goal.goal_type == "task_analysis"

  student_goal.goal.task_analysis_step_templates.ordered.each do |template|
    student_goal.student_goal_steps.find_or_create_by!(step_number: template.step_number) do |step|
      step.name                         = template.name
      step.description                  = template.description
      step.task_analysis_step_template  = template
    end
  end
end

puts "  ✓ #{StudentGoalStep.count} student goal steps instantiated"
puts "Task Analysis templates seeding complete."

# ==============================================================================
# 12. Preference Assessment Item Inventory (SRS 3.3.4, FR-047a)
# ==============================================================================
preference_inventory = {
  "Visual" => [
    "Phone", "TV", "Flashlight", "Picture books", "Balloon",
    "Crayons or markers", "Painting", "Shadow", "Beads", "Pouring liquids"
  ],
  "Sensory" => [
    "Lotion", "Play doh", "Sand play", "Water play",
    "Toys that bend or stretch", "Finger painting", "Soap bubbles", "Shining"
  ],
  "Auditory" => [
    "Toys that talk or sing", "Music", "Low pitch voice", "Stress bans"
  ],
  "Movement" => [
    "Movement", "Rolling on floor", "Being held upside down"
  ],
  "Toys" => [
    "Tube car", "Frog toy", "Coloring tube", "Fish toy", "Fleep chain",
    "Red plastic toy", "Stress ball", "Fleep red", "Piano", "Coloring glitter",
    "Body part puzzle", "Letter mat", "Gross motor handle", "See saw", "Slide",
    "Magnetic Apple", "Mobile art", "Watch", "Large & small toys", "Harmonica",
    "Stretch spring", "Bicycle", "Number book", "Seamer", "Colours"
  ]
}

preference_inventory.each do |category, item_names|
  item_names.each do |item_name|
    PreferenceInventoryItem.find_or_create_by!(category: category, name: item_name) do |item|
      item.is_active = true
    end
  end
end

puts "  ✓ #{PreferenceInventoryItem.count} preference inventory items " \
     "(#{preference_inventory.keys.size} categories)"

# ==============================================================================
# 13. ABLLS Domains & Skill Items (FR-037, SCR-TEA-002)
# ==============================================================================
puts "Seeding ABLLS domains and skill items..."

ablls_domain_definitions = [
  { code: "A", name: "Cooperation and Reinforcer Effectiveness", position: 1  },
  { code: "B", name: "Visual Performance",                       position: 2  },
  { code: "C", name: "Receptive Language",                       position: 3  },
  { code: "D", name: "Motor Imitation",                          position: 4  },
  { code: "E", name: "Vocal Imitation",                          position: 5  },
  { code: "F", name: "Requests (Mands)",                         position: 6  },
  { code: "G", name: "Labeling (Tacts)",                         position: 7  },
  { code: "H", name: "Intraverbals",                             position: 8  },
  { code: "I", name: "Spontaneous Vocalizations",                position: 9  },
  { code: "J", name: "Syntax and Grammar",                       position: 10 },
  { code: "K", name: "Play and Leisure",                         position: 11 },
  { code: "L", name: "Social Interaction",                       position: 12 },
  { code: "M", name: "Group Instruction",                        position: 13 },
  { code: "N", name: "Classroom Routines",                       position: 14 },
  { code: "P", name: "Generalized Responding",                   position: 15 },
  { code: "Q", name: "Reading",                                  position: 16 },
  { code: "R", name: "Math",                                     position: 17 },
  { code: "S", name: "Writing",                                  position: 18 },
  { code: "T", name: "Spelling",                                 position: 19 },
  { code: "U", name: "Dressing",                                 position: 20 },
  { code: "V", name: "Eating",                                   position: 21 },
  { code: "W", name: "Grooming",                                 position: 22 },
  { code: "X", name: "Toileting",                                position: 23 },
  { code: "Y", name: "Gross Motor",                              position: 24 },
  { code: "Z", name: "Fine Motor",                               position: 25 }
]

ablls_domain_records = {}
ablls_domain_definitions.each do |attrs|
  domain = AbllsDomain.find_or_create_by!(code: attrs[:code]) do |d|
    d.name      = attrs[:name]
    d.position  = attrs[:position]
    d.is_active = true
  end
  ablls_domain_records[attrs[:code]] = domain
end

puts "  ✓ #{AbllsDomain.count} ABLLS domains"

ablls_skill_items_seed = {
  "A" => [
    "Willingly goes with a teacher to the teaching area",
    "Accepts reinforcers from a teacher",
    "Sits in a chair at a table for 2 minutes",
    "Attends to reinforcers for at least 5 seconds"
  ],
  "B" => [
    "Attends to a visual stimulus for at least 3 seconds",
    "Tracks a moving object across midline",
    "Matches identical objects",
    "Matches identical pictures",
    "Sorts objects by color"
  ],
  "C" => [
    "Looks at or orients toward a sound source",
    "Follows instruction to sit down",
    "Follows instruction to stand up",
    "Follows instruction to come here",
    "Identifies common objects when named"
  ],
  "D" => [
    "Imitates gross motor movements (arms up)",
    "Imitates touching body parts",
    "Imitates actions with objects",
    "Imitates fine motor movements",
    "Imitates a sequence of 2 movements"
  ],
  "E" => [
    "Imitates vowel sounds",
    "Imitates consonant-vowel combinations",
    "Imitates single words",
    "Imitates two-word phrases"
  ],
  "F" => [
    "Requests preferred items using words or signs",
    "Requests help",
    "Requests attention from an adult",
    "Requests break or cessation of activity",
    "Requests using a multi-word phrase"
  ],
  "G" => [
    "Labels common objects",
    "Labels pictures of common objects",
    "Labels actions in pictures",
    "Labels colors",
    "Labels shapes"
  ],
  "H" => [
    "Fills in words of familiar songs",
    "Answers simple 'what' questions",
    "Answers 'where' questions about common objects",
    "Answers 'who' questions",
    "Describes the function of common objects"
  ],
  "I" => [
    "Spontaneously vocalizes (babbles/jargon)",
    "Spontaneously produces recognizable words",
    "Spontaneously produces word combinations",
    "Initiates comments about the environment"
  ],
  "J" => [
    "Uses noun-verb combinations",
    "Uses pronouns correctly",
    "Uses prepositions in speech",
    "Uses plurals correctly"
  ],
  "K" => [
    "Independently explores toys and materials",
    "Engages in cause-and-effect play",
    "Engages in pretend play",
    "Plays simple games with rules",
    "Plays cooperatively with peers for 5 minutes"
  ],
  "L" => [
    "Makes eye contact with familiar adults",
    "Responds to greetings from others",
    "Initiates greetings",
    "Shares items with peers",
    "Takes turns with peers during activities"
  ],
  "M" => [
    "Sits appropriately in a group for 3 minutes",
    "Attends to teacher during group instruction",
    "Responds to group instructions",
    "Raises hand to answer questions in group"
  ],
  "N" => [
    "Follows transition routine between activities",
    "Follows classroom clean-up routine",
    "Hangs up backpack/coat independently",
    "Lines up when directed"
  ],
  "P" => [
    "Responds to instructions in a novel environment",
    "Responds to instructions from a novel teacher",
    "Generalizes labeling to novel examples",
    "Generalizes requesting skills across settings"
  ],
  "Q" => [
    "Identifies letters of the alphabet",
    "Associates letters with their sounds",
    "Reads simple CVC words",
    "Reads common sight words"
  ],
  "R" => [
    "Rote counts to 10",
    "Counts objects with one-to-one correspondence",
    "Identifies written numerals 1-10",
    "Compares quantities (more/less)"
  ],
  "S" => [
    "Holds a writing utensil with appropriate grip",
    "Traces lines and shapes",
    "Copies letters from a model",
    "Writes first name independently"
  ],
  "T" => [
    "Spells own first name orally",
    "Spells simple CVC words",
    "Identifies beginning sounds in words"
  ],
  "U" => [
    "Removes shoes independently",
    "Puts on shoes independently",
    "Removes pullover shirt",
    "Puts on pullover shirt",
    "Fastens large buttons"
  ],
  "V" => [
    "Drinks from an open cup",
    "Eats with a spoon independently",
    "Eats with a fork independently",
    "Uses a napkin when prompted"
  ],
  "W" => [
    "Washes hands with soap and water",
    "Dries hands with a towel",
    "Brushes teeth with assistance",
    "Wipes face with a cloth"
  ],
  "X" => [
    "Indicates need to use the toilet",
    "Uses the toilet for urination",
    "Uses the toilet for bowel movements",
    "Pulls pants up/down for toileting"
  ],
  "Y" => [
    "Walks independently",
    "Runs without falling",
    "Climbs stairs alternating feet",
    "Kicks a ball forward",
    "Catches a large ball with two hands"
  ],
  "Z" => [
    "Picks up small objects using pincer grasp",
    "Stacks 6 or more blocks",
    "Strings large beads",
    "Uses scissors to cut along a straight line",
    "Completes simple puzzles (4-6 pieces)"
  ]
}

ablls_skill_items_seed.each do |domain_code, descriptions|
  domain = ablls_domain_records[domain_code]
  descriptions.each_with_index do |desc, index|
    identifier = "#{domain_code}#{index + 1}"
    AbllsSkillItem.find_or_create_by!(identifier: identifier) do |item|
      item.ablls_domain = domain
      item.description  = desc
      item.position     = index + 1
      item.is_active    = true
    end
  end
end

puts "  ✓ #{AbllsSkillItem.count} ABLLS skill items across #{AbllsDomain.count} domains"

# ==============================================================================
# 14. IUP Form Configuration (detailed field schema)
# ==============================================================================
iup_form_config = FormConfiguration.find_or_initialize_by(form_type: :iup)
iup_form_config.assign_attributes(
  form_name:         "Individual Utility Plan",
  revision_number:   1,
  revision_date:     Date.current,
  organization_name: "MELUE Foundation",
  is_default:        true,
  field_schema:      {
    "fields" => [
      {
        "id"       => "assessment_summary",
        "key"      => "assessment_summary",
        "label"    => "Assessment Summary",
        "type"     => "textarea",
        "required" => false,
        "section"  => "Student Summary"
      },
      {
        "id"         => "reinforcement_strategy",
        "key"        => "reinforcement_strategy",
        "label"      => "Reinforcement Strategy",
        "type"       => "textarea",
        "required"   => true,
        "max_length" => 5000,
        "section"    => "Behavior Management"
      },
      {
        "id"         => "consequence_plan",
        "key"        => "consequence_plan",
        "label"      => "Consequence Plan",
        "type"       => "textarea",
        "required"   => true,
        "max_length" => 5000,
        "section"    => "Behavior Management"
      },
      {
        "id"         => "family_coordination_plan",
        "key"        => "family_coordination_plan",
        "label"      => "Family Coordination Plan",
        "type"       => "textarea",
        "required"   => true,
        "max_length" => 5000,
        "section"    => "Family Support"
      },
      {
        "id"         => "behavior_reduction_plan",
        "key"        => "behavior_reduction_plan",
        "label"      => "Behavior Reduction Plan",
        "type"       => "textarea",
        "required"   => false,
        "max_length" => 5000,
        "section"    => "Behavior Management"
      },
      {
        "id"         => "crisis_plan",
        "key"        => "crisis_plan",
        "label"      => "Crisis Management Plan",
        "type"       => "textarea",
        "required"   => true,
        "max_length" => 5000,
        "section"    => "Crisis Response"
      },
      {
        "id"         => "discharge_plan",
        "key"        => "discharge_plan",
        "label"      => "Discharge Planning",
        "type"       => "textarea",
        "required"   => false,
        "max_length" => 5000,
        "section"    => "Transition Planning"
      }
    ]
  }
)
iup_form_config.save!

puts "  ✓ IUP form configuration seeded"

# ==============================================================================
# 15. FAST & MASS Assessment Questionnaires & Templates
# ==============================================================================
puts "Seeding FAST & MASS assessment questionnaires & templates..."

fast_questionnaire_template = [
  { id: 1,  code: "F1",  text: "Does the behavior occur when others are present, and does attention follow?", category: "Social - Positive", risk: :high },
  { id: 2,  code: "F2",  text: "Does the behavior occur to avoid or escape a task, demand, or request?", category: "Social - Negative", risk: :high },
  { id: 3,  code: "F3",  text: "Does the behavior produce a rewarding sensory effect without others?", category: "Automatic - Positive", risk: :high },
  { id: 4,  code: "F4",  text: "Does the behavior remove an unpleasant sensation or reduce pain?", category: "Automatic - Negative", risk: :high },
  { id: 5,  code: "F5",  text: "Does the behavior typically happen when the person is alone or unoccupied?", category: "Automatic - Positive", risk: :high },
  { id: 6,  code: "F6",  text: "Does the behavior occur during transitions or when demands increase?", category: "Social - Negative", risk: :high },
  { id: 7,  code: "F7",  text: "Does an adult typically react by giving attention or talking to the person?", category: "Social - Positive", risk: :high },
  { id: 8,  code: "F8",  text: "Is the behavior reduced when a preferred item or activity is provided freely?", category: "Social - Positive", risk: :high },
  { id: 9,  code: "F9",  text: "Does the behavior occur when access to preferred toys/food is denied?", category: "Social - Positive", risk: :moderate },
  { id: 10, code: "F10", text: "Does the behavior persist when unprompted in structured settings?", category: "Social - Negative", risk: :moderate },
  { id: 11, code: "F11", text: "Does the behavior intensify in sensory-rich or loud environments?", category: "Automatic - Negative", risk: :moderate },
  { id: 12, code: "F12", text: "Does the behavior occur repeatedly in stereotyped or ritualistic sequences?", category: "Automatic - Positive", risk: :moderate },
  { id: 13, code: "F13", text: "Does the behavior cease immediately upon teacher physical intervention?", category: "Social - Negative", risk: :moderate },
  { id: 14, code: "F14", text: "Does the behavior occur more frequently prior to meal or break times?", category: "Social - Positive", risk: :moderate },
  { id: 15, code: "F15", text: "Does the person appear distressed or agitated before the behavior starts?", category: "Automatic - Negative", risk: :moderate },
  { id: 16, code: "F16", text: "Does the behavior occur when the person is asked to share or wait for items?", category: "Social - Positive", risk: :moderate }
]

mass_questionnaire_template = [
  { id: 1,  code: "M1",  text: "Would the behavior occur continuously if left alone for long periods of time?", function: :sensory },
  { id: 2,  code: "M2",  text: "Does the behavior occur when the person is asked to do a difficult task?", function: :escape },
  { id: 3,  code: "M3",  text: "Does the behavior seem to occur when the person is ignored?", function: :attention },
  { id: 4,  code: "M4",  text: "Does the behavior occur when a preferred item is taken away?", function: :tangible },
  { id: 5,  code: "M5",  text: "Does the behavior occur when the person is left alone, with no one around?", function: :sensory },
  { id: 6,  code: "M6",  text: "Does the behavior occur following a request to perform an undesirable task?", function: :escape },
  { id: 7,  code: "M7",  text: "Does the behavior occur when attention is diverted from the person?", function: :attention },
  { id: 8,  code: "M8",  text: "Does the behavior occur when the person is denied access to a desired item or activity?", function: :tangible },
  { id: 9,  code: "M9",  text: "Does the behavior occur during a task that the person does not enjoy?", function: :escape },
  { id: 10, code: "M10", text: "Does the behavior seem to be enjoyable to the person (self-stimulatory)?", function: :sensory },
  { id: 11, code: "M11", text: "Does the behavior occur to get a reaction from others?", function: :attention },
  { id: 12, code: "M12", text: "Does the behavior occur to obtain food, toys, or a specific activity?", function: :tangible },
  { id: 13, code: "M13", text: "Does the behavior seem to calm or soothe the person when anxious?", function: :sensory },
  { id: 14, code: "M14", text: "Does the behavior occur when demands are transitioned between stations?", function: :escape },
  { id: 15, code: "M15", text: "Does the behavior stop when an adult sits next to and engages the student?", function: :attention },
  { id: 16, code: "M16", text: "Does the behavior stop immediately upon receiving an edible or toy reward?", function: :tangible },
  { id: 17, code: "M17", text: "Does the person reach for items while engaging in this behavior?", function: :tangible },
  { id: 18, code: "M18", text: "Does the behavior occur if requested objects are withheld?", function: :tangible },
  { id: 19, code: "M19", text: "Does the behavior escalate if a desired reinforcer is given to another peer?", function: :tangible },
  { id: 20, code: "M20", text: "Will the student trade engaging in the behavior if handed a high-value reinforcer?", function: :tangible }
]

puts "  ✓ FAST questionnaire template: #{fast_questionnaire_template.size} items (high & moderate risk categories)"
puts "  ✓ MASS questionnaire template: #{mass_questionnaire_template.size} items (sensory, escape, attention, tangible)"

# ==============================================================================
# 16. Historical Completed Therapy Sessions, Participants, Summaries & Trials
#     for Natnael Worku (student_d1) & Hiwot Alemu (student_d2)
# ==============================================================================
puts "Seeding historical completed sessions, participants, summaries and trials..."

# Prompt levels for trials
pl_plus = PromptLevel.find_by!(label: "+")
pl_g    = PromptLevel.find_by!(label: "G")
pl_pp   = PromptLevel.find_by!(label: "PP")
pl_fp   = PromptLevel.find_by!(label: "FP")

# Goals for Natnael (student_d1)
sg_request = student_d1.student_goals.find_by!(goal_id: request_goal.id)
sg_washing = student_d1.student_goals.find_by!(goal_id: washing_goal.id)
washing_steps = sg_washing.student_goal_steps.order(:step_number).to_a

# Goals for Hiwot (student_d2)
sg_eye      = student_d2.student_goals.find_by!(goal_id: eye_contact.id)
sg_matching = student_d2.student_goals.find_by!(goal_id: matching_goal.id)

(1..5).to_a.reverse.each do |days_ago|
  sched_date = Date.current - days_ago.days
  session_time = sched_date.to_time.change(hour: 14, min: 0)

  assignment_d1 = TeacherStudentAssignment.find_by!(
    teacher: teacher3, student: student_d1,
    session_block_definition: block_c, scheduled_date: sched_date
  )
  assignment_d2 = TeacherStudentAssignment.find_by!(
    teacher: teacher3, student: student_d2,
    session_block_definition: block_c, scheduled_date: sched_date
  )

  session = TherapySession.find_or_initialize_by(
    teacher: teacher3,
    session_block_definition: block_c,
    therapy_station: station2,
    therapy_room: room_2a,
    started_at: session_time
  )

  if session.new_record?
    session.status = "in_progress"
    session.ended_at = session_time + 45.minutes
    session.save!

    p1 = SessionParticipant.create!(
      therapy_session: session,
      student: student_d1,
      card_position: :active,
      teacher_student_assignment: assignment_d1,
      current_focus_student_goal: (days_ago.odd? ? sg_request : sg_washing)
    )

    p2 = SessionParticipant.create!(
      therapy_session: session,
      student: student_d2,
      card_position: :secondary,
      teacher_student_assignment: assignment_d2,
      current_focus_student_goal: (days_ago.odd? ? sg_eye : sg_matching)
    )

    # Exactly 2 participants exist now: transition to completed
    session.update!(status: "completed")

    SessionSummary.create!(
      therapy_session: session,
      status: "reviewed",
      qualitative_notes: "Completed session on #{sched_date}. Natnael showed strong engagement on hand washing and requesting routines. Hiwot maintained sustained eye contact and successfully completed matching tasks with gestural prompts.",
      submitted_at: session_time + 48.minutes,
      reviewed_at: session_time + 2.hours,
      reviewed_by_user: coordinator_user
    )

    # Trials for Participant 1 (Natnael)
    # Standard goal trials (sg_request) - student_goal_step MUST be nil
    [
      { pl: pl_plus, out: "correct" },
      { pl: pl_plus, out: "correct" },
      { pl: pl_g,    out: "correct" },
      { pl: pl_g,    out: "correct" },
      { pl: pl_pp,   out: "correct" },
      { pl: pl_fp,   out: "incorrect" }
    ].each_with_index do |t_data, idx|
      Trial.create!(
        therapy_session: session,
        session_participant: p1,
        student_goal: sg_request,
        student_goal_step: nil,
        prompt_level: t_data[:pl],
        prompt_label_snapshot: t_data[:pl].label,
        outcome: t_data[:out],
        client_event_id: SecureRandom.uuid,
        logged_at: session_time + (idx * 3).minutes
      )
    end

    # Task analysis trials (sg_washing) - student_goal_step MUST be present
    washing_steps.first(5).each_with_index do |step, idx|
      pl = idx < 2 ? pl_plus : (idx < 4 ? pl_g : pl_pp)
      Trial.create!(
        therapy_session: session,
        session_participant: p1,
        student_goal: sg_washing,
        student_goal_step: step,
        prompt_level: pl,
        prompt_label_snapshot: pl.label,
        outcome: "correct",
        client_event_id: SecureRandom.uuid,
        logged_at: session_time + 20.minutes + (idx * 2).minutes
      )
    end

    # Trials for Participant 2 (Hiwot)
    # Standard goal trials (sg_eye)
    [
      { pl: pl_plus, out: "correct" },
      { pl: pl_g,    out: "correct" },
      { pl: pl_g,    out: "correct" },
      { pl: pl_pp,   out: "correct" },
      { pl: pl_pp,   out: "incorrect" }
    ].each_with_index do |t_data, idx|
      Trial.create!(
        therapy_session: session,
        session_participant: p2,
        student_goal: sg_eye,
        student_goal_step: nil,
        prompt_level: t_data[:pl],
        prompt_label_snapshot: t_data[:pl].label,
        outcome: t_data[:out],
        client_event_id: SecureRandom.uuid,
        logged_at: session_time + 5.minutes + (idx * 3).minutes
      )
    end

    # Standard goal trials (sg_matching)
    [
      { pl: pl_plus, out: "correct" },
      { pl: pl_plus, out: "correct" },
      { pl: pl_g,    out: "correct" },
      { pl: pl_pp,   out: "correct" }
    ].each_with_index do |t_data, idx|
      Trial.create!(
        therapy_session: session,
        session_participant: p2,
        student_goal: sg_matching,
        student_goal_step: nil,
        prompt_level: t_data[:pl],
        prompt_label_snapshot: t_data[:pl].label,
        outcome: t_data[:out],
        client_event_id: SecureRandom.uuid,
        logged_at: session_time + 25.minutes + (idx * 3).minutes
      )
    end
  end
end

puts "  ✓ #{TherapySession.count} therapy sessions (#{TherapySession.status_completed.count} completed)"
puts "  ✓ #{SessionParticipant.count} session participants"
puts "  ✓ #{SessionSummary.count} session summaries (all reviewed by Therapy Coordinator)"
puts "  ✓ #{Trial.count} trials logged across standard and task analysis goals"

# ==============================================================================
# 17. Baseline Behavior Incidents (ABC Logs)
# ==============================================================================
puts "Seeding baseline behavior incidents (ABC logs)..."

behavior_seeds = [
  # Natnael Worku (student_d1)
  {
    student: student_d1,
    staff_member: teacher3,
    days_ago: 8,
    behavior_name: "Hitting",
    behavior_definition: "Striking table or wall with open hand or fist repeatedly",
    frequency: :occasionally,
    intensity: :moderate,
    category: :difficulty_with_transitions,
    antecedent: "Transition between activities",
    consequence: "Redirected to task",
    location: "Station 2 - Room 2A"
  },
  {
    student: student_d1,
    staff_member: teacher3,
    days_ago: 5,
    behavior_name: "Flopping",
    behavior_definition: "Throwing self on the floor suddenly when instructed to transition",
    frequency: :rarely,
    intensity: :mild,
    category: :flopping,
    antecedent: "Task demand presented",
    consequence: "Provided sensory break",
    location: "Station 2 - Room 2A"
  },
  {
    student: student_d1,
    staff_member: teacher3,
    days_ago: 3,
    behavior_name: "Unable to remain seated",
    behavior_definition: "Repeatedly standing up or leaning away from table during structured task",
    frequency: :frequently,
    intensity: :mild,
    category: :hyperactivity,
    antecedent: "Task demand presented",
    consequence: "Differential reinforcement",
    location: "Station 2 - Room 2A"
  },
  {
    student: student_d1,
    staff_member: teacher3,
    days_ago: 1,
    behavior_name: "Hitting",
    behavior_definition: "Striking table surface when preferred toy was withheld",
    frequency: :occasionally,
    intensity: :moderate,
    category: :attention_seeking,
    antecedent: "Denied access to preferred item",
    consequence: "Planned ignoring",
    location: "Station 2 - Room 2A"
  },

  # Hiwot Alemu (student_d2)
  {
    student: student_d2,
    staff_member: teacher3,
    days_ago: 9,
    behavior_name: "Screaming",
    behavior_definition: "Producing a loud high-pitched sound that can be heard across the room",
    frequency: :occasionally,
    intensity: :moderate,
    category: :making_noises,
    antecedent: "Denied access to preferred item",
    consequence: "Verbal redirection / Prompting",
    location: "Station 2 - Room 2A"
  },
  {
    student: student_d2,
    staff_member: teacher3,
    days_ago: 6,
    behavior_name: "Elopement",
    behavior_definition: "Running or wandering away from supervision (moving away at least 5 feet)",
    frequency: :rarely,
    intensity: :severe,
    category: :safety_concerns,
    antecedent: "Transition between activities",
    consequence: "Verbal redirection / Prompting",
    location: "Classroom Corridor"
  },
  {
    student: student_d2,
    staff_member: teacher3,
    days_ago: 4,
    behavior_name: "Screaming",
    behavior_definition: "Vocal protest and screaming when transitioning between rooms",
    frequency: :occasionally,
    intensity: :mild,
    category: :difficulty_with_transitions,
    antecedent: "Transition between activities",
    consequence: "Given break",
    location: "Station 2 - Room 2A"
  },
  {
    student: student_d2,
    staff_member: teacher3,
    days_ago: 2,
    behavior_name: "Unable to remain seated",
    behavior_definition: "Standing up from desk repeatedly during visual matching session",
    frequency: :frequently,
    intensity: :mild,
    category: :hyperactivity,
    antecedent: "Task demand presented",
    consequence: "Differential reinforcement",
    location: "Station 2 - Room 2A"
  },

  # Yonas Girma (student_c1)
  {
    student: student_c1,
    staff_member: teacher1,
    days_ago: 7,
    behavior_name: "Property destruction",
    behavior_definition: "Knocking materials off the work table onto the floor",
    frequency: :occasionally,
    intensity: :moderate,
    category: :attention_seeking,
    antecedent: "Task demand presented",
    consequence: "Redirected to task",
    location: "Station 1 - Room 1A"
  },
  {
    student: student_c1,
    staff_member: teacher1,
    days_ago: 2,
    behavior_name: "Screaming",
    behavior_definition: "High-pitched vocal outcry upon removal of preferred picture cards",
    frequency: :rarely,
    intensity: :moderate,
    category: :making_noises,
    antecedent: "Denied access to preferred item",
    consequence: "Provided sensory break",
    location: "Station 1 - Room 1A"
  }
]

behavior_seeds.each do |b|
  occurred = b[:days_ago].days.ago.change(hour: 14, min: 20)
  matching_session = TherapySession.find_by("DATE(started_at) = ?", occurred.to_date)

  BehaviorIncident.find_or_create_by!(
    student: b[:student],
    behavior_name: b[:behavior_name],
    occurred_at: occurred
  ) do |inc|
    inc.staff_member        = b[:staff_member]
    inc.therapy_session     = matching_session
    inc.behavior_definition = b[:behavior_definition]
    inc.frequency           = b[:frequency]
    inc.intensity           = b[:intensity]
    inc.category            = b[:category]
    inc.antecedent          = b[:antecedent]
    inc.consequence         = b[:consequence]
    inc.location            = b[:location]
    inc.additional_notes    = "Logged during routine clinical monitoring."
  end
end

puts "  ✓ #{BehaviorIncident.count} behavior incidents logged across last 10 days"

# ==============================================================================
# 18. Sensory Activities Catalogue
# ==============================================================================
puts "Seeding Sensory Activities catalogue..."

sensory_activities_seed = [
  { activity_code: "SEN-001", name: "Tactile - Sand and Water Play", display_order: 1, description: "Exploration of textured media including wet sand, water, and hydrogel beads." },
  { activity_code: "SEN-002", name: "Vestibular - Swing and Rocking", display_order: 2, description: "Linear and rotational swinging movements to stimulate vestibular input." },
  { activity_code: "SEN-003", name: "Proprioceptive - Deep Pressure / Weighted Blanket", display_order: 3, description: "Joint compression, therapy ball rolling, and weighted calming lap pads." },
  { activity_code: "SEN-004", name: "Auditory - Calming Music & Sound Tubes", display_order: 4, description: "Low-frequency rhythms, rainsticks, and noise-dampening acoustic headsets." },
  { activity_code: "SEN-005", name: "Visual - Bubble Tube & Fiber Optics", display_order: 5, description: "Illuminated color-cycling water tubes and safe handheld fiber optic strands." }
]

sensory_activity_records = sensory_activities_seed.map do |act_data|
  SensoryActivity.find_or_create_by!(activity_code: act_data[:activity_code]) do |a|
    a.name          = act_data[:name]
    a.description   = act_data[:description]
    a.display_order = act_data[:display_order]
    a.is_active     = true
  end
end

puts "  ✓ #{SensoryActivity.count} sensory activities in catalogue"

# ==============================================================================
# 19. Assessment Cycles & Full Assessment Data for "Ready for IUP" Students
#     (Saron Tekle & Biniam Hailu)
# ==============================================================================
puts "Seeding complete assessment cycles for 'ready_for_iup' students..."

[ student_b1, student_b2 ].each_with_index do |student, s_idx|
  cycle = AssessmentCycle.find_or_initialize_by(student: student)
  cycle.started_on   = 42.days.ago.to_date
  cycle.completed_on = 2.days.ago.to_date
  cycle.status       = "complete"
  cycle.save!

  # 1. ABLLS Assessment + Responses
  ablls = AbllsAssessment.find_or_initialize_by(assessment_cycle: cycle)
  ablls.staff_member = teacher1
  ablls.status       = "completed"
  ablls.started_at   = 40.days.ago
  ablls.completed_at = 3.days.ago
  ablls.save!

  AbllsSkillItem.find_each.with_index do |skill_item, item_idx|
    score =
      case (item_idx + s_idx) % 5
      when 0, 1 then "2"
      when 2    then "1"
      when 3    then "0"
      else           "not_applicable"
      end

    AbllsResponse.find_or_create_by!(
      ablls_assessment: ablls,
      ablls_skill_item: skill_item
    ) do |resp|
      resp.score = score
      resp.note  = "Evaluated in week #{(item_idx % 6) + 1} of initial 6-week assessment cycle."
    end
  end

  # 2. Skills Assessment
  skills = SkillsAssessment.find_or_initialize_by(assessment_cycle: cycle)
  skills.status           = "submitted"
  skills.progress_percent = 100
  skills.started_at       = 40.days.ago
  skills.submitted_at     = 3.days.ago
  skills.save!

  # 3. Preference Assessment + Observations
  pref = PreferenceAssessment.find_or_initialize_by(assessment_cycle: cycle)
  pref.status       = "submitted"
  pref.submitted_at = 3.days.ago
  pref.save!

  pref_items = PreferenceInventoryItem.limit(9).to_a
  pref_contexts = %w[sensory_time circle_time play_time]

  pref_items.each_with_index do |item, p_idx|
    ctx = pref_contexts[p_idx % 3]
    PreferenceObservation.find_or_create_by!(
      preference_assessment: pref,
      preference_inventory_item: item,
      context: ctx
    ) do |obs|
      obs.duration_seconds = 180 - (p_idx * 15)
      obs.frequency_count  = 10 - p_idx
      obs.rank             = p_idx + 1
      obs.tier             = p_idx < 3 ? "highest" : (p_idx < 6 ? "moderate" : "low")
      obs.combined_score   = (100.0 - (p_idx * 8.5)).round(2)
    end
  end

  # 4. Behavior Assessment
  beh = BehaviorAssessment.find_or_initialize_by(assessment_cycle: cycle)
  beh.status = "submitted"
  beh.save!

  # 5. Sensory Assessment + Records
  sensory = SensoryAssessment.find_or_initialize_by(student: student)
  sensory.status = "complete"
  sensory.save!

  sensory_activity_records.each_with_index do |act, a_idx|
    sensory.sensory_assessment_records.find_or_create_by!(sensory_activity: act) do |r|
      r.engagement_level  = SensoryAssessmentRecord::ENGAGEMENT_LEVELS[(a_idx + s_idx) % 3]
      r.response_reaction = SensoryAssessmentRecord::RESPONSE_REACTIONS[(a_idx + s_idx) % 2]
      r.remark            = "Consistent engagement observed during baseline evaluation."
    end
  end

  # 6. FAST Assessment (completed with calculated risks)
  fast = FastAssessment.find_or_initialize_by(student: student)
  fast.assessment_cycle = cycle
  fast.teacher          = teacher1
  fast_resp = {}
  (1..16).each do |q_num|
    ans = (q_num % 3 != 0)
    fast_resp[q_num.to_s] = ans
    fast_resp["F#{q_num}"] = ans if q_num <= 8
  end
  fast.responses = fast_resp
  fast.calculate_risks!
  fast.status       = "completed"
  fast.completed_at = 3.days.ago
  fast.save!

  # 7. MASS Assessment (completed with calculated scores)
  mass = MassAssessment.find_or_initialize_by(student: student)
  mass.assessment_cycle = cycle
  mass.teacher          = teacher1
  mass_resp = {}
  likert_names = [ "Never", "Almost Never", "Seldom", "Half the Time", "Usually", "Almost Always", "Always" ]
  (1..20).each do |q_num|
    val = (q_num * (s_idx + 2)) % 7
    mass_resp[q_num.to_s] = val
    mass_resp["M#{q_num}"] = likert_names[val] if q_num <= 12
  end
  mass.responses = mass_resp
  mass.calculate_scores!
  mass.status       = "completed"
  mass.completed_at = 3.days.ago
  mass.save!

  cycle.update!(status: "complete", completed_on: 2.days.ago.to_date)
end

puts "  ✓ #{AssessmentCycle.count} assessment cycles (#{AssessmentCycle.status_complete.count} complete)"
puts "  ✓ #{AbllsAssessment.count} ABLLS assessments (#{AbllsResponse.count} responses evaluated)"
puts "  ✓ #{SkillsAssessment.count} skills assessments"
puts "  ✓ #{PreferenceAssessment.count} preference assessments (#{PreferenceObservation.count} observations)"
puts "  ✓ #{BehaviorAssessment.count} behavior assessments"
puts "  ✓ #{SensoryAssessment.count} sensory assessments (#{SensoryAssessmentRecord.count} records)"
puts "  ✓ #{FastAssessment.count} FAST assessments (#{FastAssessment.status_completed.count} completed)"
puts "  ✓ #{MassAssessment.count} MASS assessments (#{MassAssessment.status_completed.count} completed)"

# ==============================================================================
# Summary
# ==============================================================================
puts ""
puts "Done! Seed summary:"
puts "  Roles & Permissions : #{Role.count} roles, #{RolePermission.count} role permissions, #{UserRole.count} user roles"
puts "  Prompt Levels       : #{PromptLevel.count}"
puts "  Stations            : #{TherapyStation.count}"
puts "  Rooms               : #{TherapyRoom.count}"
puts "  Blocks              : #{SessionBlockDefinition.count}"
puts "  Goal Domains        : #{GoalDomain.count}"
puts "  Goals               : #{Goal.count}"
puts "  ABC Options         : #{AbcDropdownOption.count}"
puts "  Form Configs        : #{FormConfiguration.count}"
puts "  Schedule Cfg        : #{SessionScheduleConfig.count}"
puts "  Staff               : #{StaffMember.count}"
puts "  Students            : #{Student.count}"
puts "  IUPs                : #{Iup.count}"
puts "  Student Goals       : #{StudentGoal.count}"
puts "  Assignments         : #{TeacherStudentAssignment.count}"
puts "  Guardian Links      : #{StudentGuardian.count}"
puts "  ABLLS Domains       : #{AbllsDomain.count}"
puts "  ABLLS Items         : #{AbllsSkillItem.count}"
puts "  Therapy Sessions    : #{TherapySession.count} (#{TherapySession.status_completed.count} completed)"
puts "  Trials Logged       : #{Trial.count}"
puts "  Session Summaries   : #{SessionSummary.count}"
puts "  Behavior Incidents  : #{BehaviorIncident.count}"
puts "  Sensory Activities  : #{SensoryActivity.count}"
puts "  Assessment Cycles   : #{AssessmentCycle.count} (#{AssessmentCycle.status_complete.count} complete)"
puts "  FAST Questionnaires : #{FastAssessment.count} completed"
puts "  MASS Questionnaires : #{MassAssessment.count} completed"
puts ""
puts "Login credentials (all passwords: #{SEED_PASSWORD}):"
puts "  System Admin         : admin@melue.foundation"
puts "  Institutional Admin  : institutional.admin@melue.foundation"
puts "  Director             : director@melue.foundation"
puts "  Program Director     : program.director@melue.foundation"
puts "  Therapy Coordinator  : coordinator@melue.foundation"
puts "  Teacher 1            : teacher1@melue.foundation"
puts "  Teacher 2            : teacher2@melue.foundation"
puts "  Teacher 3            : teacher3@melue.foundation"
puts "  Parent               : parent@melue.foundation"
puts ""
puts "Student pipeline:"
puts "  In Assessment (2)   : Amir Hassan, Tigist Bekele"
puts "  Ready for IUP (2)   : Saron Tekle, Biniam Hailu (Full 6-week assessment data)"
puts "  Active Therapy (4)  : Yonas Girma, Meron Haile, Abel Tadesse, Liya Belay"
puts "  Completed Sess. (2) : Natnael Worku, Hiwot Alemu (5 days sessions, trials & summaries)"
