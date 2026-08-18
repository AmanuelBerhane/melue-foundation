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
  s.guardian_name = "Girma Parent"
  s.guardian_phone = "555-1234"
end

student2 = Student.find_or_create_by!(first_name: "Meron", last_name: "Haile") do |s|
  s.date_of_birth = "2017-09-05"
  s.therapy_group = "basic"
  s.program_type  = "regular"
  s.status        = "active_therapy"
  s.guardian_name = "Haile Parent"
  s.guardian_phone = "555-5678"
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
# 9. RBAC: Roles & Admin User
# ==============================================================================
admin_role = Role.find_or_create_by!(name: "System Administrator") do |r|
  r.is_system_critical = true
  r.description = "Full system access"
end

teacher_role = Role.find_or_create_by!(name: "Teacher") do |r|
  r.is_system_critical = false
  r.description = "Standard therapy provider"
end

# Create permissions for staff & role management
manage_roles = Permission.find_or_create_by!(resource: 'roles', action: 'manage')
manage_staff = Permission.find_or_create_by!(resource: 'staff_members', action: 'manage')
view_roles = Permission.find_or_create_by!(resource: 'roles', action: 'index')
view_staff = Permission.find_or_create_by!(resource: 'staff_members', action: 'index')
create_roles = Permission.find_or_create_by!(resource: 'roles', action: 'create')

# Give Admin all permissions explicitly (for testing)
RolePermission.find_or_create_by!(role: admin_role, permission: manage_roles)
RolePermission.find_or_create_by!(role: admin_role, permission: manage_staff)
RolePermission.find_or_create_by!(role: admin_role, permission: view_roles)
RolePermission.find_or_create_by!(role: admin_role, permission: view_staff)
RolePermission.find_or_create_by!(role: admin_role, permission: create_roles)

admin_user = User.find_or_create_by!(email: "admin@melue.foundation") do |u|
  u.password_hash = BCrypt::Password.create("Password123!")
  u.status        = 2 # verified
end

admin_staff = StaffMember.find_or_create_by!(user: admin_user) do |s|
  s.full_name    = "System Admin"
  s.staff_number = "ADM-001"
end

UserRole.find_or_create_by!(user: admin_user, role: admin_role)
UserRole.find_or_create_by!(user: teacher1_user, role: teacher_role)

puts "  ✓ RBAC Admin seeded"

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

# ==============================================================================
# 10. ABLLS Domains & Skill Items (FR-037, SCR-TEA-002)
# ==============================================================================
# Domain codes follow the standard ABLLS-R structure.
# TODO: Replace placeholder skill item descriptions with actual clinical
#       content from the physical ABLLS form. The schema and seed mechanism
#       are fully functional — only the clinical text is placeholder.

puts "Seeding ABLLS domains and skill items..."

ablls_domain_definitions = [
  { code: "A", name: "Cooperation and Reinforcer Effectiveness", position: 1 },
  { code: "B", name: "Visual Performance", position: 2 },
  { code: "C", name: "Receptive Language", position: 3 },
  { code: "D", name: "Motor Imitation", position: 4 },
  { code: "E", name: "Vocal Imitation", position: 5 },
  { code: "F", name: "Requests (Mands)", position: 6 },
  { code: "G", name: "Labeling (Tacts)", position: 7 },
  { code: "H", name: "Intraverbals", position: 8 },
  { code: "I", name: "Spontaneous Vocalizations", position: 9 },
  { code: "J", name: "Syntax and Grammar", position: 10 },
  { code: "K", name: "Play and Leisure", position: 11 },
  { code: "L", name: "Social Interaction", position: 12 },
  { code: "M", name: "Group Instruction", position: 13 },
  { code: "N", name: "Classroom Routines", position: 14 },
  { code: "P", name: "Generalized Responding", position: 15 },
  { code: "Q", name: "Reading", position: 16 },
  { code: "R", name: "Math", position: 17 },
  { code: "S", name: "Writing", position: 18 },
  { code: "T", name: "Spelling", position: 19 },
  { code: "U", name: "Dressing", position: 20 },
  { code: "V", name: "Eating", position: 21 },
  { code: "W", name: "Grooming", position: 22 },
  { code: "X", name: "Toileting", position: 23 },
  { code: "Y", name: "Gross Motor", position: 24 },
  { code: "Z", name: "Fine Motor", position: 25 }
]

# Seed domains
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

# Seed representative skill items per domain.
# Each domain gets a configurable number of items with identifiers like B1, B2, etc.
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

puts "Done! Seed summary:"
puts "  Prompt Levels  : #{PromptLevel.count}"
puts "  Stations       : #{TherapyStation.count}"
puts "  Rooms          : #{TherapyRoom.count}"
puts "  Blocks         : #{SessionBlockDefinition.count}"
puts "  Goal Domains   : #{GoalDomain.count}"
puts "  Goals          : #{Goal.count}"
puts "  ABC Options    : #{AbcDropdownOption.count}"
puts "  Form Configs   : #{FormConfiguration.count}"
puts "  Schedule Cfg   : #{SessionScheduleConfig.count}"
puts "  Staff          : #{StaffMember.count}"
puts "  Students       : #{Student.count}"
puts "  IUPs           : #{Iup.count}"
puts "  Student Goals  : #{StudentGoal.count}"
puts "  Assignments    : #{TeacherStudentAssignment.count}"
puts "  ABLLS Domains  : #{AbllsDomain.count}"
puts "  ABLLS Items    : #{AbllsSkillItem.count}"
puts ""
puts "Login with:"
puts "  Admin  : admin@melue.foundation / Password123!"
puts "  Teacher: teacher1@melue.foundation / Password123!"
