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
# 7.5 ABC Dropdown Options
# ==============================================================================
abc_options = [
  { category: 'antecedent', label: 'Denied access to preferred item', display_order: 1 },
  { category: 'antecedent', label: 'Transition between activities', display_order: 2 },
  { category: 'antecedent', label: 'Task demand presented', display_order: 3 },
  { category: 'antecedent', label: 'Other', display_order: 99, is_other: true },

  { category: 'behavior', label: 'Hitting', display_order: 1 },
  { category: 'behavior', label: 'Screaming', display_order: 2 },
  { category: 'behavior', label: 'Property destruction', display_order: 3 },
  { category: 'behavior', label: 'Other', display_order: 99, is_other: true },

  { category: 'consequence', label: 'Removed from area', display_order: 1 },
  { category: 'consequence', label: 'Given break', display_order: 2 },
  { category: 'consequence', label: 'Redirected to task', display_order: 3 },
  { category: 'consequence', label: 'Other', display_order: 99, is_other: true }
]

abc_options.each do |attrs|
  AbcDropdownOption.find_or_create_by!(category: attrs[:category], label: attrs[:label]) do |opt|
    opt.display_order = attrs[:display_order]
    opt.is_active = true
    opt.is_other = attrs[:is_other] || false
  end
end

puts "  ✓ #{AbcDropdownOption.count} ABC dropdown options"

# ==============================================================================
# 7.6 Form Configurations
# ==============================================================================
form_configs = [
  {
    form_type: 'enrollment',
    form_name: 'Student Enrollment Form',
    revision_number: 1,
    organization_name: 'Default Organization',
    field_schema: { 'fields' => [] }
  },
  {
    form_type: 'iup',
    form_name: 'Individualized Plan (IUP)',
    revision_number: 1,
    organization_name: 'Default Organization',
    is_default: true,
    field_schema: { 'fields' => [] }
  },
  {
    form_type: 'ablls',
    form_name: 'ABLLS Assessment',
    revision_number: 1,
    organization_name: 'Default Organization',
    field_schema: { 'fields' => [] }
  }
]

form_configs.each do |attrs|
  FormConfiguration.find_or_create_by!(form_type: attrs[:form_type]) do |fc|
    fc.form_name = attrs[:form_name]
    fc.revision_number = attrs[:revision_number]
    fc.organization_name = attrs[:organization_name]
    fc.is_default = attrs[:is_default] || false
    fc.field_schema = attrs[:field_schema]
  end
end

puts "  ✓ #{FormConfiguration.count} form configurations"

# ==============================================================================
# 7.7 Session Schedule Configuration
# ==============================================================================
SessionScheduleConfig.instance

puts "  ✓ Session schedule configuration initialized"

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
# 9. Preference Assessment Item Inventory (SRS 3.3.4, FR-047a)
# ==============================================================================
# Mirrors the physical "Preference Assessment.pdf" form exactly. Administrators
# may extend this catalogue via the Form Builder (SCR-ADMIN-001); teachers who
# need a one-off item add it as a custom item on the observation instead, which
# never lands here (FR-047f).
preference_inventory = {
  "Visual" => [
    "Phone",
    "TV",
    "Flashlight",
    "Picture books",
    "Balloon",
    "Crayons or markers",
    "Painting",
    "Shadow",
    "Beads",
    "Pouring liquids"
  ],
  "Sensory" => [
    "Lotion",
    "Play doh",
    "Sand play",
    "Water play",
    "Toys that bend or stretch",
    "Finger painting",
    "Soap bubbles",
    "Shining"
  ],
  "Auditory" => [
    "Toys that talk or sing",
    "Music",
    "Low pitch voice",
    "Stress bans"
  ],
  "Movement" => [
    "Movement",
    "Rolling on floor",
    "Being held upside down"
  ],
  "Toys" => [
    "Tube car",
    "Frog toy",
    "Coloring tube",
    "Fish toy",
    "Fleep chain",
    "Red plastic toy",
    "Stress ball",
    "Fleep red",
    "Piano",
    "Coloring glitter",
    "Body part puzzle",
    "Letter mat",
    "Gross motor handle",
    "See saw",
    "Slide",
    "Magnetic Apple",
    "Mobile art",
    "Watch",
    "Large & small toys",
    "Harmonica",
    "Stretch spring",
    "Bicycle",
    "Number book",
    "Seamer",
    "Colours"
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

puts ""

# ============================================================
# FR-095 — Task Analysis Goal Bank, Step Templates & Student Steps
# ============================================================

puts "Seeding Task Analysis Step Templates..."

task_analysis_goals = {
  "Washing Hands" => [
    "Turn on water",
    "Wet hands",
    "Apply soap",
    "Lather for 20 seconds",
    "Rinse hands",
    "Turn off water",
    "Dry hands"
  ],
  "Toileting - Urination" => [
    "Initiate toileting",
    "Go to toilet",
    "Pull down pants",
    "Sit / stand at toilet",
    "Urinate",
    "Wipe",
    "Pull up pants"
  ],
  "Toileting - Request" => [
    "Initiate request",
    "Use verbal / sign / device",
    "Wait for acknowledgment"
  ],
  "Dressing - Shoes" => [
    "Pick up shoe",
    "Put foot in shoe",
    "Fasten / close shoe"
  ],
  "Dressing - Pants" => [
    "Pick up pants",
    "Step into pants",
    "Pull pants up",
    "Fasten (button / zip)"
  ]
}

# Idempotent goal creation — every goal needs a valid goal_domain
task_analysis_goals.each do |goal_name, steps|
  goal = Goal.find_or_create_by!(
    name: goal_name,
    goal_domain: domain_records["Daily Living Skills"]
  ) do |g|
    g.goal_type = "task_analysis"
    g.is_active = true
  end
  goal.update!(goal_type: "task_analysis") unless goal.goal_type == "task_analysis"

  steps.each_with_index do |step_name, index|
    goal.task_analysis_step_templates.find_or_create_by!(step_number: index + 1) do |t|
      t.name = step_name
    end
  end

  puts "  ✓ Seeded #{steps.size} steps for '#{goal_name}'"
end

# Give student1 an active task_analysis goal so steps can be instantiated
washing_hands_goal = Goal.find_by!(name: "Washing Hands")
StudentGoal.find_or_create_by!(iup: iup1, goal: washing_hands_goal, student: student1) do |sg|
  sg.therapy_station = station1
  sg.status          = "active"
  sg.progress_percent = 0.0
end

# Instantiate StudentGoalStep records for every active task_analysis goal
StudentGoal.where(status: %w[active in_progress]).find_each do |student_goal|
  next unless student_goal.goal.goal_type == "task_analysis"

  student_goal.goal.task_analysis_step_templates.ordered.each do |template|
    student_goal.student_goal_steps.find_or_create_by!(step_number: template.step_number) do |step|
      step.name                     = template.name
      step.description              = template.description
      step.task_analysis_step_template = template
    end
  end
end

puts "  ✓ #{StudentGoalStep.count} student goal steps instantiated"
puts "Task Analysis templates seeding complete."

puts "Done! Seed summary:"
puts "  Prompt Levels : #{PromptLevel.count}"
puts "  Stations      : #{TherapyStation.count}"
puts "  Rooms         : #{TherapyRoom.count}"
puts "  Blocks        : #{SessionBlockDefinition.count}"
puts "  Goal Domains  : #{GoalDomain.count}"
puts "  Goals         : #{Goal.count}"
puts "  ABC Options   : #{AbcDropdownOption.count}"
puts "  Form Configs  : #{FormConfiguration.count}"
puts "  Schedule Cfg  : #{SessionScheduleConfig.count}"
puts "  Staff         : #{StaffMember.count}"
puts "  Students      : #{Student.count}"
puts "  IUPs          : #{Iup.count}"
puts "  Student Goals : #{StudentGoal.count}"
puts "  Assignments   : #{TeacherStudentAssignment.count}"
puts "  Roles         : #{Role.count}"
puts "  Role Assign   : #{RoleAssignment.count}"
puts "  Pref. Items   : #{PreferenceInventoryItem.count}"
puts ""
puts "Login with: teacher1@melue.foundation / Password123!"
