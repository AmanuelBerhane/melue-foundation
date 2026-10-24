# frozen_string_literal: true

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File 5/5: db/seeds/05_child_studentA_full_story.rb
#
# Complete Clinical Lifecycle of Student A (SRS 3.2 – 3.7):
#   1. Student Profile & Guardian Linking (Parent One / parent_user)
#   2. Complete 6-Week Assessment Cycle & Evaluations:
#      - ABLLS-R Assessment & Skill Scores (C, D, E, G, K, L, F, U, V, W)
#      - MAS (Motivation Assessment Scale) Target: Screaming -> Tangible
#      - FAST Assessment Records (Screaming, Biting, Flopping, Elopement)
#      - Preference Assessment (Highest, Moderate, Low/Unapproached)
#      - Sensory Assessment (All 12 Activities, Vestibular Aversion on Swing)
#   3. Active IUP & Assigned Standard Goals (Station 1 & Station 2)
#      - STRICT RESTRICTION: Exclusively standard goals, ZERO Task Analysis
#   4. Authentic Longitudinal ABC Incident Chronology (13 Physical Dossier Logs)
#   5. Historical Completed Therapy Sessions, Summaries & Standard Trials
#      - STRICT RESTRICTION: student_goal_step: nil on every single trial
# ==============================================================================

ActiveRecord::Base.transaction do
  puts "\n================================================================================"
  puts "  [SEED 05/05] STUDENT A — COMPLETE AUTHENTIC CLINICAL LIFECYCLE"
  puts "================================================================================\n"

  # ----------------------------------------------------------------------------
  # 0. Lookup Administrative References
  # ----------------------------------------------------------------------------
  puts "--> Fetching administrative references..."

  station1 = TherapyStation.find_by!(name: "Station 1")
  station2 = TherapyStation.find_by!(name: "Station 2")

  room_1a = TherapyRoom.find_by!(name: "Room 1A", therapy_station: station1)
  room_1b = TherapyRoom.find_by!(name: "Room 1B", therapy_station: station1)
  room_2a = TherapyRoom.find_by!(name: "Room 2A", therapy_station: station2)

  morning_block_a = SessionBlockDefinition.find_by!(name: "Morning Block A")
  morning_block_b = SessionBlockDefinition.find_by!(name: "Morning Block B")

  teacher1 = StaffMember.joins(:user).find_by!(users: { email: "teacher1@melue.foundation" }) # Teacher One
  teacher2 = StaffMember.joins(:user).find_by!(users: { email: "teacher2@melue.foundation" }) # Teacher Two

  coordinator_user  = User.find_by!(email: "coordinator@melue.foundation")
  coordinator_staff = StaffMember.find_by!(user: coordinator_user)
  director_user     = User.find_by!(email: "director@melue.foundation")
  parent_user       = User.find_by!(email: "parent@melue.foundation")
  parent_guardian   = Guardian.find_by!(user: parent_user)

  prompt_fp  = PromptLevel.find_by!(label: "FP")
  prompt_pp  = PromptLevel.find_by!(label: "PP")
  prompt_g   = PromptLevel.find_by!(label: "G")
  prompt_ind = PromptLevel.find_by!(label: "+")

  puts "    ✓ References loaded: Stations 1 & 2, Rooms 1A/1B/2A, Teachers 1 & 2, Coordinator, Director, Parent."

  # ----------------------------------------------------------------------------
  # 1. Student Profile & Guardian Linking (SRS 3.2)
  # ----------------------------------------------------------------------------
  puts "\n--> [1/5] Provisioning Student A profile and linking parent guardian..."

  student_a = Student.find_or_initialize_by(
    first_name: "Student",
    last_name:  "A"
  )

  student_a.assign_attributes(
    middle_name:           nil,
    date_of_birth:         Date.parse("2021-02-15"),
    therapy_group:         "basic",
    program_type:          "regular",
    status:                "active_therapy",
    diagnosis:             "Autism Spectrum Disorder (ASD)",
    guardian_name:         parent_guardian.full_name,
    guardian_phone:        parent_guardian.phone,
    guardian_email:        parent_user.email,
    enrolled_at:           Date.parse("2025-10-01"),
    assessment_started_at: Date.parse("2025-10-15"),
    custom_fields:         {
      "official_diagnosis_date" => "2024-08-07",
      "family_delay_history"    => "No neurodevelopmental family delay",
      "seizure_history"         => "No seizure history",
      "restrictions"            => "No known physical or environmental restrictions",
      "medications"             => "Taking Inulin for gut health",
      "previous_schooling"      => "Never been to school before",
      "household_members"       => [ "Mother", "Father", "Aunt", "Sister" ]
    }
  )
  student_a.save!
  adel = student_a

  # Idempotent Guardian Association
  StudentGuardian.find_or_create_by!(
    student:  student_a,
    guardian: parent_guardian
  ) do |sg|
    sg.relationship       = "Mother"
    sg.is_primary_contact = true
  end

  puts "    ✓ Student A profile active: ID [#{student_a.student_id}] | Guardian: #{parent_guardian.full_name} linked."

  # ----------------------------------------------------------------------------
  # 2. 6-Week Assessment Cycle & Comprehensive Evaluations (SRS 3.3)
  # ----------------------------------------------------------------------------
  puts "\n--> [2/5] Provisioning 6-Week Assessment Cycle & 5-Part Clinical Evaluation..."

  cycle = AssessmentCycle.find_or_initialize_by(
    student:    student_a,
    started_on: Date.parse("2025-10-15")
  )
  cycle.completed_on = Date.parse("2025-11-26")
  cycle.status       = "complete"
  cycle.save!

  # 2a. ABLLS-R Assessment & Skill Scores (from official radar chart)
  ablls = AbllsAssessment.find_or_initialize_by(
    assessment_cycle: cycle
  )
  ablls.assign_attributes(
    staff_member: teacher1,
    started_at:   Date.parse("2025-10-15").to_time,
    completed_at: Date.parse("2025-11-26").to_time,
    status:       "completed"
  )
  ablls.save!

  # Domain scores from physical radar chart:
  # C (Receptive): 3.5 | D (Motor): 2.5 | E (Vocal): 2.2 | G (Label): 1.4 | K (Play): 0.4
  # L (Social): 4.5 | F (Request/Mand): 4.5 | U (Dressing): 4.0 | V (Eating): 2.9 | W (Grooming): 6.0
  target_domain_scores = {
    "C" => "2",
    "D" => "1",
    "E" => "1",
    "F" => "2",
    "G" => "1",
    "K" => "0",
    "L" => "2",
    "U" => "2",
    "V" => "1",
    "W" => "2"
  }

  AbllsDomain.where(code: target_domain_scores.keys).includes(:ablls_skill_items).each do |domain|
    target_score = target_domain_scores[domain.code]
    domain.ablls_skill_items.each_with_index do |skill_item, s_idx|
      # Slightly vary scores around domain baseline
      item_score = if target_score == "0"
                     "0"
      elsif target_score == "2"
                     (s_idx.zero? ? "2" : (s_idx == 1 ? "2" : "1"))
      else
                     (s_idx.even? ? "1" : "0")
      end

      AbllsResponse.find_or_initialize_by(
        ablls_assessment: ablls,
        ablls_skill_item: skill_item
      ).tap do |resp|
        resp.score = item_score
        resp.save!
      end
    end
  end

  # 2b. MAS (Motivation Assessment Scale) — Target Behavior: Screaming
  mass = MassAssessment.find_or_initialize_by(
    student:          adel,
    assessment_cycle: cycle
  )
  mass.assign_attributes(
    teacher:      teacher1,
    status:       "completed",
    completed_at: Date.parse("2025-11-20").to_time,
    responses:    {
      "target_behavior" => "Screaming",
      "evaluator"       => "Teacher One",
      "1" => 4, "2" => 5, "3" => 3, "4" => 2,
      "5" => 5, "6" => 4, "7" => 1, "8" => 2,
      "9" => 4, "10" => 3, "11" => 2, "12" => 1,
      "13" => 3, "14" => 4, "15" => 2, "16" => 5,
      "17" => 4, "18" => 5, "19" => 4, "20" => 5
    },
    scores:       {
      "tangible"         => 35,
      "sensory"          => 31,
      "escape"           => 17,
      "attention"        => 19,
      "rankings"         => {
        "Tangible"         => { "total" => 35, "mean" => 3.5, "rank" => 1 },
        "Sensory"          => { "total" => 31, "mean" => 2.7, "rank" => 2 },
        "Demands"          => { "total" => 17, "mean" => 2.1, "rank" => 3 },
        "Social Attention" => { "total" => 19, "mean" => 1.9, "rank" => 4 },
        "Attention Escape" => { "total" => 12, "mean" => 1.08, "rank" => 5 }
      },
      "primary_function" => "Tangible / Access to Preferred Objects"
    }
  )
  mass.save!

  # 2c. FAST Assessment — Evaluated Behaviors & Maintaining Functions
  fast = FastAssessment.find_or_initialize_by(
    student:          adel,
    assessment_cycle: cycle
  )
  fast.assign_attributes(
    teacher:      teacher1,
    status:       "completed",
    completed_at: Date.parse("2025-11-20").to_time,
    responses:    {
      "target_behaviors"      => [ "Screaming", "Biting others", "Flopping", "Elopement" ],
      "maintaining_functions" => [ "Access to tangibles", "Escape from transitions/demands" ],
      "1" => true,  "2" => false, "3" => true,  "4" => true,
      "5" => true,  "6" => true,  "7" => false, "8" => false,
      "9" => true,  "10" => false, "11" => false, "12" => false,
      "13" => false, "14" => false, "15" => false, "16" => false,
      "F1" => false, "F2" => true, "F3" => false, "F4" => false,
      "F5" => false, "F6" => true, "F7" => false, "F8" => true
    }
  )
  fast.calculate_risks!

  # 2d. Preference Assessment Observations
  pref = PreferenceAssessment.find_or_initialize_by(
    assessment_cycle: cycle
  )
  pref.status       = "submitted"
  pref.submitted_at = Date.parse("2025-11-18").to_time
  pref.save!

  tier_items = [
    # Highest Tier
    { name: "Stretch spring",   category: "Toys", tier: "highest",  duration: 320, freq: 8, approached: true, rank: 1 },
    { name: "Sensory tube",     category: "Sensory", tier: "highest", duration: 300, freq: 7, approached: true, rank: 2 },
    { name: "Red chair",        category: "Toys", tier: "highest",  duration: 280, freq: 6, approached: true, rank: 3 },
    { name: "Body part puzzle", category: "Toys", tier: "highest",  duration: 260, freq: 5, approached: true, rank: 4 },
    { name: "Magnetic Apple",   category: "Toys", tier: "highest",  duration: 250, freq: 5, approached: true, rank: 5 },
    { name: "Building blocks",  category: "Toys", tier: "highest",  duration: 240, freq: 5, approached: true, rank: 6 },

    # Moderate Tier
    { name: "Frog toy",         category: "Toys", tier: "moderate", duration: 160, freq: 4, approached: true, rank: 7 },
    { name: "Calming tube",     category: "Sensory", tier: "moderate", duration: 150, freq: 3, approached: true, rank: 8 },
    { name: "Fish toy",         category: "Toys", tier: "moderate", duration: 140, freq: 3, approached: true, rank: 9 },
    { name: "Red plastic toy",  category: "Toys", tier: "moderate", duration: 130, freq: 3, approached: true, rank: 10 },
    { name: "Stress ball",      category: "Sensory", tier: "moderate", duration: 120, freq: 2, approached: true, rank: 11 },
    { name: "Flexy red",        category: "Sensory", tier: "moderate", duration: 110, freq: 2, approached: true, rank: 12 },
    { name: "Calming glitter",  category: "Visual", tier: "moderate", duration: 100, freq: 2, approached: true, rank: 13 },
    { name: "Crayons",          category: "Visual", tier: "moderate", duration: 90,  freq: 2, approached: true, rank: 14 },

    # Low / Unapproached Tier
    { name: "Marble",           category: "Sensory", tier: "low", duration: 0, freq: 0, approached: false, rank: 15 },
    { name: "Watch",            category: "Sensory", tier: "low", duration: 0, freq: 0, approached: false, rank: 16 },
    { name: "Small/large toys", category: "Toys", tier: "low", duration: 0, freq: 0, approached: false, rank: 17 },
    { name: "Harmonica",        category: "Auditory", tier: "low", duration: 0, freq: 0, approached: false, rank: 18 },
    { name: "Keys",             category: "Auditory", tier: "low", duration: 0, freq: 0, approached: false, rank: 19 }
  ]

  tier_items.each do |item_data|
    inv_item = PreferenceInventoryItem.find_by("LOWER(name) = ?", item_data[:name].downcase)

    obs = if inv_item
            PreferenceObservation.find_or_initialize_by(
              preference_assessment:     pref,
              preference_inventory_item: inv_item,
              context:                   :play_time
            )
    else
            PreferenceObservation.find_or_initialize_by(
              preference_assessment: pref,
              custom_item_name:      item_data[:name],
              context:               :play_time
            )
    end

    obs.assign_attributes(
      custom_item_category: (inv_item ? nil : item_data[:category]),
      tier:                 item_data[:tier],
      duration_seconds:     item_data[:duration],
      frequency_count:      item_data[:freq],
      approached:           item_data[:approached],
      rank:                 item_data[:rank],
      notes:                "Authentic observation from physical Preference Evaluation dossier."
    )
    obs.save!
  end

  # 2e. Sensory Time Engagement Assessment (All 12 Activities)
  sensory = SensoryAssessment.find_or_initialize_by(student: adel)
  sensory.status = "complete"
  sensory.save!

  sensory_profiles = {
    "SEN-001" => { level: "Independent",            reaction: "Enjoyed", remark: "Highly engaged with shaving foam and lotion on tactile board." },
    "SEN-002" => { level: "Independent",            reaction: "Enjoyed", remark: "Relaxes and responds positively to gentle shoulder and hand massage." },
    "SEN-003" => { level: "Independent",            reaction: "Enjoyed", remark: "Consistently seeks jumping on trampoline; smiles and laughs." },
    "SEN-004" => { level: "Independent",            reaction: "Enjoyed", remark: "Enjoys rhythmically bouncing on large therapy ball." },
    "SEN-005" => { level: "Full Physical Prompt",   reaction: "Neutral", remark: "Requires two-handed physical guidance across balance beam." },
    "SEN-006" => { level: "Independent",            reaction: "Enjoyed", remark: "Loves jumping onto crash pad; deep pressure input calms him." },
    "SEN-007" => { level: "Independent",            reaction: "Enjoyed", remark: "Calm and focused during sand exploration and tactile digging." },
    "SEN-008" => { level: "Partial Physical Prompt", reaction: "Neutral", remark: "Tolerates reciprocal motion with staff with light guidance." },
    "SEN-009" => { level: "Independent",            reaction: "Enjoyed", remark: "Climbs ladder independently and slides down with positive affect." },
    "SEN-010" => { level: "Not Applicable",          reaction: "Refused", remark: "Refuses swing (strong vestibular aversion); displays anxiety." },
    "SEN-011" => { level: "Partial Physical Prompt", reaction: "Neutral", remark: "Requires physical prompt on pedals for bilateral leg coordination." },
    "SEN-012" => { level: "Partial Physical Prompt", reaction: "Neutral", remark: "Requires physical guidance for structured peer turn taking." }
  }

  SensoryActivity.order(:activity_code).each do |activity|
    profile = sensory_profiles[activity.activity_code] || { level: "Independent", reaction: "Neutral", remark: "Baseline response observed." }

    rec = SensoryAssessmentRecord.find_or_initialize_by(
      sensory_assessment: sensory,
      sensory_activity:   activity
    )
    rec.assign_attributes(
      engagement_level:  profile[:level],
      response_reaction: profile[:reaction],
      remark:            profile[:remark]
    )
    rec.save!
  end

  puts "    ✓ 6-Week Assessment Cycle completed: ABLLS-R radar profile, MAS Screaming function, FAST, Preference tiers & 12 Sensory records."

  # ----------------------------------------------------------------------------
  # 3. Active IUP & Assigned Standard Goals (SRS 3.4 & 3.5)
  # ----------------------------------------------------------------------------
  puts "\n--> [3/5] Provisioning Active IUP & 4 Standard Goals (2 per station, ZERO Task Analysis)..."

  iup = Iup.find_or_initialize_by(
    student: adel,
    status:  "active"
  )
  iup.assign_attributes(
    assessment_cycle:  cycle,
    created_by_user:   coordinator_user,
    finalized_by_user: director_user,
    finalized_on:      Date.parse("2025-12-01")
  )
  iup.save!

  # Up to 2 standard goals per Station (Station 1: Basic Skills, Station 2: Daily Living Skills)
  # CRITICAL RESTRICTION: Every goal MUST be standard (goal_type: "standard")
  adel_goal_specs = [
    # Station 1 (Basic Skills)
    {
      station:  station1,
      title:    "Functional Requesting (Mand via sign or distal point)",
      progress: 20.0,
      note:     "Focus on distal point and single-word vocal mand for preferred tangibles."
    },
    {
      station:  station1,
      title:    "Vocal imitation of series of speech sounds",
      progress: 15.0,
      note:     "Echoic training targeting 2-sound sequences (e.g. /ba-ba/, /ma-ma/)."
    },

    # Station 2 (Daily Living Skills)
    {
      station:  station2,
      title:    "Washing Hands",
      progress: 40.0,
      note:     "Standard clinical hand washing routine with visual sequence prompt."
    },
    {
      station:  station2,
      title:    "Dressing - Shoes",
      progress: 50.0,
      note:     "Standard shoe donning and velcro fastening protocol."
    }
  ]

  # Clean up non-target goals to respect the 2 goals per station constraint
  target_goals = adel_goal_specs.map { |g| Goal.find_by!(name: g[:title], goal_type: "standard") }
  iup.student_goals.where.not(goal_id: target_goals.map(&:id)).destroy_all

  adel_goals_map = {}

  adel_goal_specs.each do |g_spec|
    goal = Goal.find_by!(name: g_spec[:title], goal_type: "standard")

    sg = StudentGoal.find_or_initialize_by(
      student: adel,
      iup:     iup,
      goal:    goal
    )
    sg.assign_attributes(
      therapy_station:  g_spec[:station],
      status:           "active",
      progress_percent: g_spec[:progress],
      clinical_note:    g_spec[:note]
    )
    sg.save!

    adel_goals_map[goal.name] = sg
  end

  puts "    ✓ Active IUP established with 4 Standard Goals (Station 1: Requesting & Vocal | Station 2: Hands & Shoes)."

  # ----------------------------------------------------------------------------
  # 4. Authentic Longitudinal ABC Incident Chronology (SRS 3.6.3)
  # ----------------------------------------------------------------------------
  puts "\n--> [4/5] Seeding 13 Authentic Handwritten ABC Incident Logs from Clinical Dossier..."

  abc_logs = [
    {
      time:       "2026-02-12 17:43:00",
      staff:      teacher1,
      location:   "Station 2",
      behavior:   "Biting others",
      definition: "Placing teeth on another person's hand/arm and applying pressure",
      category:   :safety_concerns,
      frequency:  :rarely,
      intensity:  :severe,
      antecedent: "One-to-one teacher said 3,2,1 give me pencils",
      consequence: "Verbal redirection 'dots 123'",
      notes:      "Physical Dossier Log #1: Transferred demand placed to relinquish preferred pencils."
    },
    {
      time:       "2026-02-13 17:38:00",
      staff:      teacher1,
      location:   "Therapy door",
      behavior:   "Biting others",
      definition: "Placing teeth on another person's hand/arm and applying pressure",
      category:   :safety_concerns,
      frequency:  :rarely,
      intensity:  :severe,
      antecedent: "One teacher said let's go outside",
      consequence: "Teacher said '3, 2, 1 STOP'",
      notes:      "Physical Dossier Log #2: Transition demand to depart room."
    },
    {
      time:       "2026-02-13 15:41:00",
      staff:      teacher2,
      location:   "Therapy room",
      behavior:   "Biting others",
      definition: "Placing teeth on another person's hand and applying pressure",
      category:   :safety_concerns,
      frequency:  :rarely,
      intensity:  :severe,
      antecedent: "Instructor said 3,2,1 give me your block during soccer play",
      consequence: "Removed hand, advised to request appropriately",
      notes:      "Physical Dossier Log #3: Bit instructor's hand when asked to share soccer toy."
    },
    {
      time:       "2026-02-13 16:13:00",
      staff:      teacher2,
      location:   "Therapy room",
      behavior:   "Biting others",
      definition: "Placing teeth on another person's abdomen and applying pressure",
      category:   :safety_concerns,
      frequency:  :rarely,
      intensity:  :severe,
      antecedent: "Transition demand placed",
      consequence: "Moved away, advised not to do it again",
      notes:      "Physical Dossier Log #4: Lunged toward abdomen during table cleanup transition."
    },
    {
      time:       "2026-02-12 16:38:00",
      staff:      teacher2,
      location:   "Sand area",
      behavior:   "Flopping",
      definition: "Throwing self on the floor suddenly to escape demand",
      category:   :flopping,
      frequency:  :frequently,
      intensity:  :moderate,
      antecedent: "Went to sand area; instructor said 'It's music time'",
      consequence: "Instructed to get up, provided wait time to stand independently",
      notes:      "Physical Dossier Log #5: Refused music time transition from preferred sand."
    },
    {
      time:       "2026-02-12 14:18:00",
      staff:      teacher2,
      location:   "Circle time",
      behavior:   "Flopping",
      definition: "Throwing self on the floor suddenly",
      category:   :flopping,
      frequency:  :frequently,
      intensity:  :moderate,
      antecedent: "Went to circle area; instructor said 'Go back to the chair'",
      consequence: "Instructed to get up, provided wait time",
      notes:      "Physical Dossier Log #6: Dropped to knees and floor when redirected to chair."
    },
    {
      time:       "2026-02-13 16:23:00",
      staff:      teacher2,
      location:   "Outside",
      behavior:   "Flopping",
      definition: "Throwing self on the floor suddenly",
      category:   :flopping,
      frequency:  :frequently,
      intensity:  :moderate,
      antecedent: "Went to sand area; instructor said 'It's snack time'",
      consequence: "Provided wait time to stand up independently",
      notes:      "Physical Dossier Log #7: Flopped onto grass when told outdoor play ended."
    },
    {
      time:       "2026-02-06 15:19:00",
      staff:      teacher2,
      location:   "Therapy room",
      behavior:   "Flopping",
      definition: "Throwing self on the floor suddenly",
      category:   :flopping,
      frequency:  :frequently,
      intensity:  :moderate,
      antecedent: "Instructor said '3,2,1 what do you want?'",
      consequence: "Provided wait time for independent standing",
      notes:      "Physical Dossier Log #8: Frustrated by mand delay; dropped to rug."
    },
    {
      time:       "2026-02-06 17:12:00",
      staff:      teacher1,
      location:   "Main therapy circle",
      behavior:   "Scratching",
      definition: "Reaching out fingers to scrape teacher's forearm",
      category:   :safety_concerns,
      frequency:  :rarely,
      intensity:  :moderate,
      antecedent: "Circle time group routine",
      consequence: "Teacher held hand and returned him to place",
      notes:      "Physical Dossier Log #9: Attempted to break away from group circle."
    },
    {
      time:       "2025-10-20 15:57:00",
      staff:      teacher2,
      location:   "Therapy room",
      behavior:   "Unable to remain seated",
      definition: "Repeatedly standing up or leaning in seated position within structured activities",
      category:   :hyperactivity,
      frequency:  :constantly,
      intensity:  :mild,
      antecedent: "Instructor got up to write report",
      consequence: "Instructed to return to seat",
      notes:      "Physical Dossier Log #10: Immediately stood and left table when attention removed."
    },
    {
      time:       "2025-10-23 15:30:00",
      staff:      teacher2,
      location:   "Therapy door",
      behavior:   "Elopement",
      definition: "Running or wandering away from supervision through open door",
      category:   :elopement,
      frequency:  :occasionally,
      intensity:  :severe,
      antecedent: "Therapy room door opened",
      consequence: "Returned to room",
      notes:      "Physical Dossier Log #11: Sprinted toward hallway when door cracked open."
    },
    {
      time:       "2025-10-23 16:27:00",
      staff:      teacher2,
      location:   "Snack place",
      behavior:   "Elopement",
      definition: "Running away from table immediately after completing task",
      category:   :elopement,
      frequency:  :occasionally,
      intensity:  :severe,
      antecedent: "Finished snack",
      consequence: "Instructed to return to snack place",
      notes:      "Physical Dossier Log #12: Bolted toward hallway before plate was cleaned."
    },
    {
      time:       "2025-10-23 15:11:00",
      staff:      teacher2,
      location:   "Therapy room",
      behavior:   "Screaming",
      definition: "Producing a loud high-pitched sound that can be heard across the room",
      category:   :making_noises,
      frequency:  :frequently,
      intensity:  :severe,
      antecedent: "Instructor said 3,2,1 give me your blocks",
      consequence: "Waited until calmed down, advised not to scream",
      notes:      "Physical Dossier Log #13: High-pitch protest upon demand to surrender building blocks."
    }
  ]

  abc_logs.each do |log|
    occ_time = Time.zone.parse(log[:time])

    incident = BehaviorIncident.find_or_initialize_by(
      student:     adel,
      occurred_at: occ_time
    )

    incident.assign_attributes(
      staff_member:        log[:staff],
      location:            log[:location],
      behavior_name:       log[:behavior],
      behavior_definition: log[:definition],
      category:            log[:category],
      frequency:           log[:frequency],
      intensity:           log[:intensity],
      antecedent:          log[:antecedent],
      consequence:         log[:consequence],
      additional_notes:    log[:notes]
    )
    incident.save!
  end

  puts "    ✓ 13 Authentic ABC incident logs seeded covering Oct 2025 through Feb 2026."

  # ----------------------------------------------------------------------------
  # 5. Historical Completed Therapy Sessions & Standard Trials
  # ----------------------------------------------------------------------------
  puts "\n--> [5/5] Provisioning 3 Historical Completed Sessions & Standard Trials..."

  # Today's Scheduled Assignment: Morning Block A | Station 1 | Room 1A | Teacher 1
  today = Date.current
  TeacherStudentAssignment.find_or_initialize_by(
    student:                   adel,
    session_block_definition: morning_block_a,
    scheduled_date:           today
  ).tap do |tsa|
    tsa.teacher         = teacher1
    tsa.therapy_station = station1
    tsa.therapy_room    = room_1a
    tsa.status          = "scheduled"
    tsa.save!
  end

  # 3 Historical Sessions on Clinical Dossier Dates (Feb 10, Feb 11, Feb 12, 2026)
  historical_sessions_config = [
    {
      date:       Date.parse("2026-02-10"),
      teacher:    teacher1,
      block:      morning_block_a,
      station:    station1,
      room:       room_1a,
      start_time: "08:00",
      end_time:   "09:30",
      focus_goal: adel_goals_map["Functional Requesting (Mand via sign or distal point)"],
      alt_goal:   adel_goals_map["Vocal imitation of series of speech sounds"],
      notes:      "Student A demonstrated emerging distal point with partial physical prompt. Reduced vocal protest during transitions."
    },
    {
      date:       Date.parse("2026-02-11"),
      teacher:    teacher1,
      block:      morning_block_a,
      station:    station1,
      room:       room_1a,
      start_time: "08:00",
      end_time:   "09:30",
      focus_goal: adel_goals_map["Functional Requesting (Mand via sign or distal point)"],
      alt_goal:   adel_goals_map["Vocal imitation of series of speech sounds"],
      notes:      "Strong motivation for stretch spring and sensory tube. Responded to gesture prompts on 4 consecutive trials."
    },
    {
      date:       Date.parse("2026-02-12"),
      teacher:    teacher2,
      block:      morning_block_b,
      station:    station1,
      room:       room_1b,
      start_time: "09:45",
      end_time:   "11:15",
      focus_goal: adel_goals_map["Vocal imitation of series of speech sounds"],
      alt_goal:   adel_goals_map["Functional Requesting (Mand via sign or distal point)"],
      notes:      "Vocal imitation trials completed. Good eye contact maintained during structured table routine."
    }
  ]

  historical_sessions_config.each_with_index do |s_cfg, s_idx|
    # A. Historical Teacher-Student Assignment
    tsa = TeacherStudentAssignment.find_or_initialize_by(
      student:                   adel,
      session_block_definition: s_cfg[:block],
      scheduled_date:           s_cfg[:date]
    )
    tsa.assign_attributes(
      teacher:         s_cfg[:teacher],
      therapy_station: s_cfg[:station],
      therapy_room:    s_cfg[:room],
      status:          "completed"
    )
    tsa.save!

    # B. Completed Therapy Session
    s_start = s_cfg[:date].to_time.change(
      hour: s_cfg[:start_time].split(":").first.to_i,
      min:  s_cfg[:start_time].split(":").last.to_i
    )
    s_end   = s_cfg[:date].to_time.change(
      hour: s_cfg[:end_time].split(":").first.to_i,
      min:  s_cfg[:end_time].split(":").last.to_i
    )

    session = TherapySession.where(
      teacher:                  s_cfg[:teacher],
      session_block_definition: s_cfg[:block],
      therapy_station:          s_cfg[:station],
      therapy_room:             s_cfg[:room]
    ).where("started_at >= ? AND started_at <= ?", s_cfg[:date].beginning_of_day, s_cfg[:date].end_of_day).first

    if session.nil?
      session = TherapySession.new(
        teacher:                  s_cfg[:teacher],
        session_block_definition: s_cfg[:block],
        therapy_station:          s_cfg[:station],
        therapy_room:             s_cfg[:room],
        started_at:               s_start,
        ended_at:                 s_end,
        status:                   "in_progress"
      )
      session.save!(validate: false)

      participant = SessionParticipant.create!(
        therapy_session:               session,
        student:                       adel,
        teacher_student_assignment:    tsa,
        card_position:                 :active,
        current_focus_student_goal:    s_cfg[:focus_goal]
      )

      session.update!(status: "completed")
    else
      participant = SessionParticipant.find_or_create_by!(
        therapy_session: session,
        student:         adel
      ) do |sp|
        sp.teacher_student_assignment = tsa
        sp.card_position              = :active
        sp.current_focus_student_goal = s_cfg[:focus_goal]
      end
    end

    # C. Reviewed Session Summary
    summary = SessionSummary.find_or_initialize_by(therapy_session: session)
    summary.assign_attributes(
      status:             "reviewed",
      submitted_at:       s_end + 10.minutes,
      reviewed_by_user:   coordinator_user,
      reviewed_at:        s_end + 45.minutes,
      qualitative_notes:  s_cfg[:notes]
    )
    summary.save!

    # D. Realistic Standard Trials
    # CRITICAL RESTRICTION: student_goal_step MUST be nil on every trial
    goals_for_trials = [ s_cfg[:focus_goal], s_cfg[:alt_goal] ].compact

    10.times do |t_idx|
      goal = goals_for_trials[t_idx % goals_for_trials.length]
      event_id = "trial-seed-student-a-#{session.id}-#{t_idx + 1}"

      next if Trial.exists?(client_event_id: event_id)

      prompt = case t_idx
      when 0..2 then prompt_fp
      when 3..5 then prompt_pp
      when 6..7 then prompt_g
      else prompt_ind
      end

      outcome = case t_idx
      when 0 then "no_response"
      when 1..2 then "incorrect"
      when 3..4 then "correct"
      when 5 then "incorrect"
      else "correct"
      end

      trial_time = s_start + (5 + t_idx * 7).minutes

      Trial.create!(
        client_event_id:       event_id,
        therapy_session:       session,
        session_participant:   participant,
        student_goal:          goal,
        student_goal_step:     nil, # STRICTLY NIL per instruction
        prompt_level:          prompt,
        prompt_label_snapshot: prompt.label,
        outcome:               outcome,
        logged_at:             trial_time
      )
    end
  end

  puts "    ✓ 3 Historical completed sessions, participant records, reviewed summaries and 30 standard trials provisioned."

  puts "\n" + ("=" * 80)
  puts "  [SEED 05/05] COMPLETE: STUDENT A FULL CLINICAL STORY ESTABLISHED"
  puts ("=" * 80) + "\n"
end
