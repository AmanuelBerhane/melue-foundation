# frozen_string_literal: true

# Seeds for local development and CI.
# All operations use find_or_create_by! to keep seeds idempotent.

puts "Seeding..."

# ==============================================================================
# 1. Prompt Levels (FR-094 — configurable, not hardcoded)
# ==============================================================================
prompt_levels = [
  { label: "FP",  color: "#EF4444", display_order: 1 }, # Full Prompt
  { label: "PP",  color: "#F97316", display_order: 2 }, # Partial Prompt
  { label: "G",   color: "#EAB308", display_order: 3 }, # Gesture
  { label: "+",   color: "#22C55E", display_order: 4 }  # Independent
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
# 2. Therapy Stations & Rooms
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
blocks = [
  { name: "Morning Block A",   start_time: "08:00", end_time: "09:30", round: "morning" },
  { name: "Morning Block B",   start_time: "09:45", end_time: "11:15", round: "morning" },
  { name: "Afternoon Block A", start_time: "12:30", end_time: "14:00", round: "afternoon" },
  { name: "Afternoon Block B", start_time: "14:15", end_time: "15:45", round: "afternoon" }
]

blocks.each do |attrs|
  SessionBlockDefinition.find_or_create_by!(name: attrs[:name]) do |b|
    b.start_time = attrs[:start_time]
    b.end_time   = attrs[:end_time]
    b.round      = attrs[:round]
    b.is_active  = true
  end
end

puts "  ✓ #{SessionBlockDefinition.count} session blocks"

# ==============================================================================
# 4. Goal Domains & Goals
# ==============================================================================
domains = [
  { name: "Communication",          display_order: 1 },
  { name: "Social Skills",          display_order: 2 },
  { name: "Daily Living Skills",    display_order: 3 },
  { name: "Motor Skills",           display_order: 4 },
  { name: "Academic Readiness",     display_order: 5 },
  { name: "Behavior Reduction",     display_order: 6 }
]

domain_records = domains.each_with_object({}) do |attrs, hash|
  hash[attrs[:name]] = GoalDomain.find_or_create_by!(name: attrs[:name]) do |d|
    d.display_order = attrs[:display_order]
    d.is_active     = true
  end
end

goals_seed = [
  { domain: "Communication",       name: "Request preferred items using words",          type: "standard" },
  { domain: "Communication",       name: "Follow two-step verbal instructions",          type: "standard" },
  { domain: "Social Skills",       name: "Initiate greeting with peers",                 type: "standard" },
  { domain: "Social Skills",       name: "Take turns in structured play",                type: "standard" },
  { domain: "Daily Living Skills", name: "Wash hands independently",                     type: "task_analysis" },
  { domain: "Daily Living Skills", name: "Pack school bag",                              type: "task_analysis" },
  { domain: "Motor Skills",        name: "Maintain pencil grip for 3 minutes",           type: "standard" },
  { domain: "Academic Readiness",  name: "Identify letters A–Z by name",                 type: "standard" },
  { domain: "Behavior Reduction",  name: "Reduce out-of-seat behavior during circle time", type: "standard" }
]

goals_seed.each do |attrs|
  Goal.find_or_create_by!(
    name: attrs[:name],
    goal_domain: domain_records[attrs[:domain]]
  ) do |g|
    g.goal_type = attrs[:type]
    g.is_active = true
  end
end

puts "  ✓ #{GoalDomain.count} goal domains, #{Goal.count} goals"

# ==============================================================================
# 5. Staff Users & Profiles
# ==============================================================================
teacher1_user = User.find_or_create_by!(email: "teacher1@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create("Password123!")
  u.status        = 2 # verified
end

teacher2_user = User.find_or_create_by!(email: "teacher2@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create("Password123!")
  u.status        = 2
end

teacher1 = StaffMember.find_or_create_by!(user: teacher1_user) do |s|
  s.full_name    = "Abeba Tadesse"
  s.staff_number = "STF-001"
end

teacher2 = StaffMember.find_or_create_by!(user: teacher2_user) do |s|
  s.full_name    = "Dawit Bekele"
  s.staff_number = "STF-002"
end

puts "  ✓ #{StaffMember.count} staff members"

# ==============================================================================
# 6. Students
# ==============================================================================
student1 = Student.find_or_create_by!(first_name: "Yonas", last_name: "Girma") do |s|
  s.date_of_birth = "2018-04-12"
  s.therapy_group = "basic"
  s.program_type  = "regular"
  s.status        = "active_therapy"
end

student2 = Student.find_or_create_by!(first_name: "Meron", last_name: "Haile") do |s|
  s.date_of_birth = "2017-09-05"
  s.therapy_group = "basic"
  s.program_type  = "regular"
  s.status        = "active_therapy"
end

puts "  ✓ #{Student.count} students"

# ==============================================================================
# 7. IUPs & Student Goals (tied to Station 1)
# ==============================================================================
comm_goal = Goal.find_by!(name: "Request preferred items using words")
social_goal = Goal.find_by!(name: "Initiate greeting with peers")

iup1 = Iup.find_or_create_by!(student: student1, status: "active") do |i|
  i.finalized_on = Date.current - 30.days
end

iup2 = Iup.find_or_create_by!(student: student2, status: "active") do |i|
  i.finalized_on = Date.current - 30.days
end

StudentGoal.find_or_create_by!(iup: iup1, goal: comm_goal, student: student1) do |sg|
  sg.therapy_station = station1
  sg.status          = "active"
  sg.progress_percent = 45.0
end

StudentGoal.find_or_create_by!(iup: iup2, goal: social_goal, student: student2) do |sg|
  sg.therapy_station = station1
  sg.status          = "active"
  sg.progress_percent = 30.0
end

puts "  ✓ #{Iup.count} IUPs, #{StudentGoal.count} student goals"

# ==============================================================================
# 8. Today's Teacher-Student Assignments (Morning Block A, Station 1, Room 1A)
# ==============================================================================
block_a  = SessionBlockDefinition.find_by!(name: "Morning Block A")
room_1a  = TherapyRoom.find_by!(name: "Room 1A")

TeacherStudentAssignment.find_or_create_by!(
  teacher:                  teacher1,
  student:                  student1,
  session_block_definition: block_a,
  scheduled_date:           Date.current
) do |a|
  a.therapy_station = station1
  a.therapy_room    = room_1a
  a.status          = "scheduled"
end

TeacherStudentAssignment.find_or_create_by!(
  teacher:                  teacher1,
  student:                  student2,
  session_block_definition: block_a,
  scheduled_date:           Date.current
) do |a|
  a.therapy_station = station1
  a.therapy_room    = room_1a
  a.status          = "scheduled"
end

puts "  ✓ #{TeacherStudentAssignment.count} assignments (#{TeacherStudentAssignment.for_today.count} for today)"

# ==============================================================================
# 9. Roles (FR-006 — role-based routing) & assignments
# ==============================================================================
role_names = [
  Role::Names::TEACHER,
  Role::Names::THERAPY_COORDINATOR,
  Role::Names::PROGRAM_DIRECTOR,
  Role::Names::DIRECTOR,
  Role::Names::INSTITUTIONAL_ADMIN,
  Role::Names::SYSTEM_ADMIN,
  Role::Names::PARENT
]

role_names.each do |name|
  is_system_critical = [ Role::Names::SYSTEM_ADMIN, Role::Names::INSTITUTIONAL_ADMIN ].include?(name)
  Role.find_or_create_by!(name: name) do |r|
    r.is_system_critical = is_system_critical
    r.is_active          = true
  end
end

puts "  ✓ #{Role.count} roles"

# Assign the seeded teacher users their Teacher role (idempotent).
[ teacher1_user, teacher2_user ].each do |u|
  u.assign_role(Role::Names::TEACHER)
end

puts "  ✓ role assignments for #{RoleAssignment.count} assignments"

puts ""
puts "Done! Seed summary:"
puts "  Prompt Levels : #{PromptLevel.count}"
puts "  Stations      : #{TherapyStation.count}"
puts "  Rooms         : #{TherapyRoom.count}"
puts "  Blocks        : #{SessionBlockDefinition.count}"
puts "  Goal Domains  : #{GoalDomain.count}"
puts "  Goals         : #{Goal.count}"
puts "  Staff         : #{StaffMember.count}"
puts "  Students      : #{Student.count}"
puts "  IUPs          : #{Iup.count}"
puts "  Student Goals : #{StudentGoal.count}"
puts "  Assignments   : #{TeacherStudentAssignment.count}"
puts "  Roles         : #{Role.count}"
puts "  Role Assign   : #{RoleAssignment.count}"
puts ""
puts "Login with: teacher1@melue.foundation / Password123!"
