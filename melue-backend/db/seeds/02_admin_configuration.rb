# frozen_string_literal: true

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File 2/4: db/seeds/02_admin_configuration.rb
#
# Scope:
#   1. Prompt Hierarchy Levels (FP, PP, G, +) with Standard Color Coding
#   2. Therapy Stations & Physical Rooms (Station 1 & 2, Rooms 1A-1D, 2A-2D)
#   3. Session Block Definitions (Morning & Afternoon Block Rounds)
#   4. Singleton Session Schedule Configuration (Capacities, Durations, Expiry)
#   5. Authentic Form Configurations & Clinical Schemas (MCTC-TRP Series & IUP)
# ==============================================================================

puts "\n" + ("=" * 80)
puts "  [SEED 02/04] ADMIN CONFIGURATION, ROOM INFRASTRUCTURE & FORM SCHEMAS"
puts ("=" * 80)

ActiveRecord::Base.transaction do
  # ----------------------------------------------------------------------------
  # 1. Prompt Levels (FR-094, FR-142)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning 4 Canonical Prompt Hierarchy Levels..."

  prompt_levels = [
    { label: "FP", color: "#EF4444", display_order: 1, name: "Full Physical / Full Prompt" },
    { label: "PP", color: "#F97316", display_order: 2, name: "Partial Physical / Partial Prompt" },
    { label: "G",  color: "#EAB308", display_order: 3, name: "Gesture Prompt" },
    { label: "+",  color: "#22C55E", display_order: 4, name: "Independent Execution" }
  ]

  prompt_levels.each do |attrs|
    pl = PromptLevel.find_or_initialize_by(label: attrs[:label])
    pl.color         = attrs[:color]
    pl.display_order = attrs[:display_order]
    pl.is_active     = true
    pl.discarded_at  = nil
    pl.save!

    puts "    ✓ Prompt Level: #{attrs[:label].ljust(4)} | Color: #{attrs[:color]} | Order: #{attrs[:display_order]} (#{attrs[:name]})"
  end

  # ----------------------------------------------------------------------------
  # 2. Therapy Stations & Physical Rooms (SRS 2.3.4)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Therapy Stations & Physical Rooms (1A–1D, 2A–2D)..."

  station1 = TherapyStation.find_or_initialize_by(name: "Station 1")
  station1.discarded_at = nil
  station1.save!

  station2 = TherapyStation.find_or_initialize_by(name: "Station 2")
  station2.discarded_at = nil
  station2.save!

  room_mappings = [
    [ station1, "Room 1A" ],
    [ station1, "Room 1B" ],
    [ station1, "Room 1C" ],
    [ station1, "Room 1D" ],
    [ station2, "Room 2A" ],
    [ station2, "Room 2B" ],
    [ station2, "Room 2C" ],
    [ station2, "Room 2D" ]
  ]

  room_mappings.each do |station, room_name|
    room = TherapyRoom.find_or_initialize_by(therapy_station: station, name: room_name)
    room.discarded_at = nil
    room.save!

    puts "    ✓ #{station.name} -> #{room.name}"
  end

  # ----------------------------------------------------------------------------
  # 3. Session Block Definitions & Schedules (SRS FR-150, FR-151)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Session Block Definitions (Morning & Afternoon Rounds)..."

  blocks_seed = [
    { name: "Morning Block A",   start_time: "08:00", end_time: "09:30", round: "morning"   },
    { name: "Morning Block B",   start_time: "09:45", end_time: "11:15", round: "morning"   },
    { name: "Afternoon Block A", start_time: "12:30", end_time: "14:00", round: "afternoon" },
    { name: "Afternoon Block B", start_time: "14:15", end_time: "15:45", round: "afternoon" }
  ]

  blocks_seed.each do |attrs|
    block = SessionBlockDefinition.find_or_initialize_by(name: attrs[:name])
    block.start_time   = attrs[:start_time]
    block.end_time     = attrs[:end_time]
    block.round        = attrs[:round]
    block.is_active    = true
    block.discarded_at = nil
    block.save!

    puts "    ✓ #{block.name.ljust(20)} [#{block.round.upcase}] #{attrs[:start_time]} - #{attrs[:end_time]}"
  end

  # ----------------------------------------------------------------------------
  # 4. Session Schedule Configuration Singleton (SRS FR-150, NFR-022)
  # ----------------------------------------------------------------------------
  puts "\n--> Initializing Session Schedule Configuration Singleton..."

  schedule_config = SessionScheduleConfig.first_or_initialize
  schedule_config.morning_start_time           = "08:00"
  schedule_config.morning_end_time             = "11:30"
  schedule_config.afternoon_start_time         = "12:30"
  schedule_config.afternoon_end_time           = "16:00"
  schedule_config.pre_therapy_duration_minutes = 15
  schedule_config.station_1_duration_minutes   = 45
  schedule_config.station_2_duration_minutes   = 45
  schedule_config.staff_to_student_capacity    = 2
  schedule_config.draft_expiry_days            = 14
  schedule_config.save!

  puts "    ✓ Session Schedule Config Singleton active:"
  puts "      - Morning Hours:      #{schedule_config.morning_start_time.strftime('%H:%M')} - #{schedule_config.morning_end_time.strftime('%H:%M')}"
  puts "      - Afternoon Hours:    #{schedule_config.afternoon_start_time.strftime('%H:%M')} - #{schedule_config.afternoon_end_time.strftime('%H:%M')}"
  puts "      - Pre-Therapy Time:   #{schedule_config.pre_therapy_duration_minutes} minutes"
  puts "      - Station Durations:  Station 1: #{schedule_config.station_1_duration_minutes}m | Station 2: #{schedule_config.station_2_duration_minutes}m"
  puts "      - Clinician Capacity: #{schedule_config.staff_to_student_capacity} students per block"
  puts "      - Draft Alert Window: #{schedule_config.draft_expiry_days} days"

  # ----------------------------------------------------------------------------
  # 5. Form Configurations & Clinical Metadata (SRS Section 3 & FR-139b/c)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning 7 Authentic Physical Form Configurations & Schemas..."

  # Helper for section tags
  form_configs_data = [
    # ── Form 1: Enrollment Interview Form ─────────────────────────────────────
    {
      form_name: "Enrollment Interview Form",
      form_type: :enrollment,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2024-07-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-006",
          "revision" => "REV.-1 July 2024",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 3"
        },
        "fields" => [
          # Section: Student Info
          { "id" => "enr_headshot", "type" => "file_upload", "label" => "Child Identification Headshot Photo", "required" => true, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_first_name", "type" => "text", "label" => "Child First Name", "required" => true, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_middle_name", "type" => "text", "label" => "Child Middle Name", "required" => false, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_last_name", "type" => "text", "label" => "Child Last Name", "required" => true, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_dob", "type" => "date", "label" => "Date of Birth", "required" => true, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_gender", "type" => "dropdown", "label" => "Gender", "required" => true, "visible" => true, "section" => "Student Info", "options" => [ "Male", "Female" ] },
          { "id" => "enr_diagnosis", "type" => "dropdown", "label" => "Primary Clinical Diagnosis", "required" => true, "visible" => true, "section" => "Student Info", "options" => [ "Autism Spectrum Disorder (ASD)", "Sensory Processing Disorder", "Developmental Delay", "Speech & Language Impairment", "Other Neurodevelopmental Condition" ] },
          { "id" => "enr_diagnosis_date", "type" => "date", "label" => "Date of Formal Diagnosis", "required" => true, "visible" => true, "section" => "Student Info" },
          { "id" => "enr_program_type", "type" => "dropdown", "label" => "Recommended Placement Program", "required" => true, "visible" => true, "section" => "Student Info", "options" => [ "Regular Morning Program", "Regular Afternoon Program", "Pulled-Out Individual Program" ] },
          { "id" => "enr_therapy_group", "type" => "dropdown", "label" => "Therapy Group Track", "required" => true, "visible" => true, "section" => "Student Info", "options" => [ "Basic Therapy", "Functional Living Skills" ] },

          # Section: Parent Info
          { "id" => "enr_household", "type" => "textarea", "label" => "Household Structure & Co-habitants (Father, Mother, Siblings, Extended Family)", "required" => true, "visible" => true, "section" => "Parent Info" },
          { "id" => "enr_guardian_name", "type" => "text", "label" => "Primary Parent / Guardian Full Name", "required" => true, "visible" => true, "section" => "Parent Info" },
          { "id" => "enr_guardian_relationship", "type" => "dropdown", "label" => "Relationship to Child", "required" => true, "visible" => true, "section" => "Parent Info", "options" => [ "Mother", "Father", "Grandparent", "Legal Guardian", "Aunt / Uncle" ] },
          { "id" => "enr_guardian_phone", "type" => "text", "label" => "Primary Contact Telephone", "required" => true, "visible" => true, "section" => "Parent Info" },
          { "id" => "enr_guardian_email", "type" => "text", "label" => "Guardian Email Address", "required" => false, "visible" => true, "section" => "Parent Info" },
          { "id" => "enr_emergency_contact", "type" => "text", "label" => "Emergency Secondary Contact & Phone", "required" => true, "visible" => true, "section" => "Parent Info" },

          # Section: Medical Info & Reinforcers
          { "id" => "enr_dev_history", "type" => "textarea", "label" => "Developmental History (Motor milestones, speech emergence, zero schooling history)", "required" => true, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_medical_restrictions", "type" => "textarea", "label" => "Medical Notes, Inulin/Prescription Medications & Dietary Restrictions", "required" => true, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_reinforcer_visual", "type" => "checkbox", "label" => "Visual Reinforcer Sensitivity (LED lights, spinning tubes, colorful rings, puzzle blocks)", "required" => false, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_reinforcer_auditory", "type" => "checkbox", "label" => "Auditory Reinforcer Sensitivity (Music blocks, nursery rhymes, xylophone, auditory praise)", "required" => false, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_reinforcer_tactile", "type" => "checkbox", "label" => "Tactile Reinforcer Preference (Shaving foam, stretch spring, squishy ball, textured pads)", "required" => false, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_reinforcer_kinetic", "type" => "checkbox", "label" => "Kinetic & Movement Preferences (Crash pad, vestibular swing, trampolines, gentle rocking)", "required" => false, "visible" => true, "section" => "Medical Info" },
          { "id" => "enr_baseline_video", "type" => "file_upload", "label" => "Baseline Behavioral Assessment Video (Optional - FR-024b)", "required" => false, "visible" => true, "section" => "Medical Info" }
        ],
        "customSections" => [ "Student Info", "Parent Info", "Medical Info" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 2: ABLLS-R Assessment Form ──────────────────────────────────────
    {
      form_name: "ABLLS-R Assessment Form",
      form_type: :ablls,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-08-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-012-01",
          "revision" => "August 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          # Domain A: Visual Performance
          { "id" => "A1", "type" => "radio", "label" => "A1: Matches identical real objects to objects", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "A2", "type" => "radio", "label" => "A2: Matches identical pictures to pictures", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "A3", "type" => "radio", "label" => "A3: Sorts non-identical objects by category", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "A4", "type" => "radio", "label" => "A4: Completes 4-6 piece inset frame puzzle", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain B: Motor Imitation
          { "id" => "B1", "type" => "radio", "label" => "B1: Gross motor imitation (Clap hands, touch head)", "required" => true, "visible" => true, "section" => "Motor Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "B2", "type" => "radio", "label" => "B2: Imitation of motor actions with objects (Roll car, ring bell)", "required" => true, "visible" => true, "section" => "Motor Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "B3", "type" => "radio", "label" => "B3: Fine motor finger imitation (Pincer grip, tap fingers)", "required" => true, "visible" => true, "section" => "Motor Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain C: Vocal Imitation
          { "id" => "C1", "type" => "radio", "label" => "C1: Vocal imitation of basic open vowel sounds (ah, ee, oo)", "required" => true, "visible" => true, "section" => "Vocal Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "C2", "type" => "radio", "label" => "C2: Vocal imitation of consonant-vowel syllables (ma, ba, da)", "required" => true, "visible" => true, "section" => "Vocal Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain D: Receptive Language
          { "id" => "D1", "type" => "radio", "label" => "D1: Responds to own spoken first name by orienting head/eye contact", "required" => true, "visible" => true, "section" => "Receptive Language", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "D2", "type" => "radio", "label" => "D2: Follows 1-step direct instruction (Sit down, stand up, come here)", "required" => true, "visible" => true, "section" => "Receptive Language", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "D3", "type" => "radio", "label" => "D3: Points to 4 major body parts on request (Eyes, nose, ears, hands)", "required" => true, "visible" => true, "section" => "Receptive Language", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain E: Requesting (Mands)
          { "id" => "E1", "type" => "radio", "label" => "E1: Requests preferred tangible items using 1-word utterance or PECS", "required" => true, "visible" => true, "section" => "Requesting (Mands)", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "E2", "type" => "radio", "label" => "E2: Mands for physical assistance or opening containers", "required" => true, "visible" => true, "section" => "Requesting (Mands)", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain F: Play & Leisure
          { "id" => "F1", "type" => "radio", "label" => "F1: Engages with toys constructively rather than mouthing or perseverating", "required" => true, "visible" => true, "section" => "Play and Leisure", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "F2", "type" => "radio", "label" => "F2: Sustained independent play with preferred toy for 5 continuous minutes", "required" => true, "visible" => true, "section" => "Play and Leisure", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain G: Social Interaction
          { "id" => "G1", "type" => "radio", "label" => "G1: Accepts gentle touch or physical proximity of peers without aggression", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "G2", "type" => "radio", "label" => "G2: Takes alternating turns with clinician during structured games", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Domain I: Dressing & Self-Help
          { "id" => "I1", "type" => "radio", "label" => "I1: Cooperates with unlacing and removing shoes upon arrival", "required" => true, "visible" => true, "section" => "Dressing", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },
          { "id" => "I2", "type" => "radio", "label" => "I2: Pulls up pants after toilet routine with partial physical guidance", "required" => true, "visible" => true, "section" => "Dressing", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Developing", "3 — Mastered", "N/A" ] },

          # Evaluator Summary & Radar Metadata
          { "id" => "ablls_evaluator_remarks", "type" => "textarea", "label" => "Evaluator Clinical Remarks & Assessment Radar Mapping Notes", "required" => true, "visible" => true, "section" => "General" }
        ],
        "customSections" => [ "Visual Performance", "Motor Imitation", "Vocal Imitation", "Receptive Language", "Requesting (Mands)", "Play and Leisure", "Social Interaction", "Dressing", "General" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 3: Behavior Incident Form (ABC Only) ─────────────────────────────
    {
      form_name: "Behavior Incident Form",
      form_type: :abc_data_sheet,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-07-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "TRP-006-ABC",
          "revision" => "Rev 01",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          { "id" => "b_ant", "type" => "dropdown", "label" => "Antecedent (A)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Demand / Non-Preferred Task", "Transition / Room Change", "Denied Access to Preferred Item", "Attention Diverted", "Sensory Overload / Overstimulation", "Fatigue / Discomfort", "Unstructured Free Time" ] },
          { "id" => "b_beh", "type" => "dropdown", "label" => "Behavior (B)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Screaming / Vocal Tantrum", "Biting Others", "Flopping to Floor", "Elopement", "Scratching / Pinching", "Self-Injurious Hand/Arm Biting", "Throwing Materials", "Refusal / Non-Compliance" ] },
          { "id" => "b_con", "type" => "dropdown", "label" => "Consequence (C)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Differential Reinforcement (DRA)", "Planned Ignoring / Extinction", "Physical Guidance / Redirection", "Prompt Functional Mand", "Sensory Calming Space", "Demand Pause / Work Modification" ] }
        ],
        "customSections" => [ "ABC Tracking" ],
        "deletedSections" => [],
        "history" => []
      }
    },
    {
      form_name: "ABC Data Sheet",
      form_type: :abc_data_sheet,
      organization_name: "Melu'e Foundation",
      revision_number: 7,
      revision_date: Date.parse("2025-07-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "TRP-006",
          "revision" => "Rev 07",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          { "id" => "b_ant", "type" => "dropdown", "label" => "Antecedent (A)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Demand / Non-Preferred Task", "Transition / Room Change", "Denied Access to Preferred Item", "Attention Diverted", "Sensory Overload / Overstimulation", "Fatigue / Discomfort", "Unstructured Free Time" ] },
          { "id" => "b_beh", "type" => "dropdown", "label" => "Behavior (B)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Screaming / Vocal Tantrum", "Biting Others", "Flopping to Floor", "Elopement", "Scratching / Pinching", "Self-Injurious Hand/Arm Biting", "Throwing Materials", "Refusal / Non-Compliance" ] },
          { "id" => "b_con", "type" => "dropdown", "label" => "Consequence (C)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Differential Reinforcement (DRA)", "Planned Ignoring / Extinction", "Physical Guidance / Redirection", "Prompt Functional Mand", "Sensory Calming Space", "Demand Pause / Work Modification" ] }
        ],
        "customSections" => [ "ABC Tracking" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form: Behavioral Assessment (Full Config) ─────────────────────────────
    {
      form_name: "Behavioral Assessment",
      form_type: :behavioral_assessment,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-08-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-006-BEH",
          "revision" => "August 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 2"
        },
        "fields" => [
          # Location, Timer / Duration, Frequency, Intensity
          { "id" => "b_loc", "type" => "dropdown", "label" => "Session Room / Physical Location", "required" => true, "visible" => true, "section" => "Incident Details", "options" => [ "Room 1A", "Room 1B", "Room 1C", "Room 1D", "Room 2A", "Room 2B", "Room 2C", "Room 2D", "Sensory Station", "Hallway / Transit", "Playground", "Restroom" ] },
          { "id" => "b_dur", "type" => "number", "label" => "Duration / Timer (mins)", "required" => true, "visible" => true, "section" => "Incident Details" },
          { "id" => "b_freq", "type" => "number", "label" => "Episode Frequency / Count", "required" => true, "visible" => true, "section" => "Incident Details" },
          { "id" => "b_int", "type" => "dropdown", "label" => "Behavior Severity Intensity", "required" => true, "visible" => true, "section" => "Incident Details", "options" => [ "Low", "Medium", "High" ] },

          # ABC Tracking
          { "id" => "abc_ant", "type" => "dropdown", "label" => "Antecedent Category (Trigger)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Demand / Non-Preferred Table Task", "Transition to Station 2 / Room Change", "Denied Access to Preferred Item (e.g. iPad, Spring)", "Attention Diverted to Other Student", "Sensory Overload / Overstimulation", "Fatigue / Hunger / Biological Discomfort", "Unstructured Free Waiting Time" ] },
          { "id" => "abc_beh", "type" => "dropdown", "label" => "Primary Behavior Topography", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Screaming & Vocal Tantrum", "Biting Others (Clinician / Peer)", "Flopping to Floor & Body Stiffening", "Elopement from Seat / Room", "Scratching / Pinching Clinician", "Self-Injurious Hand/Arm Biting", "Throwing Therapy Materials", "Unable to Remain Seated at Table" ] },
          { "id" => "abc_con", "type" => "dropdown", "label" => "Structured Consequence Protocol Applied", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Differential Reinforcement of Alternative (DRA)", "Planned Ignoring / Extinction Protocol", "Physical Guidance / Neutral Redirection", "Prompt Functional Mand (Break / Toy card)", "Sensory Calming Space Transfer (Crash Pad)", "Demand Pause / Work Task Modification" ] },
          { "id" => "abc_goal", "type" => "dropdown", "label" => "Correlated Active IUP Goal Target", "required" => false, "visible" => true, "section" => "ABC Tracking", "options" => [ "Goal 1: Functional Mand for Break", "Goal 2: Remaining Seated for 10 Minutes", "Goal 3: Requesting Preferred Toy using Word", "Goal 4: Safe Hand Transition / No Aggression", "Emergent Baseline (Unassigned Target)" ] },

          # MASS Items
          { "id" => "M1", "type" => "radio", "label" => "Would the behavior occur continuously if left alone for long periods of time?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M2", "type" => "radio", "label" => "Does the behavior occur when the person is asked to do a difficult task?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M3", "type" => "radio", "label" => "Does the behavior seem to occur when the person is ignored?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M4", "type" => "radio", "label" => "Does the behavior occur when a preferred item is taken away?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M5", "type" => "radio", "label" => "Does the behavior occur when the person is left alone, with no one around?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M6", "type" => "radio", "label" => "Does the behavior occur following a request to perform an undesirable task?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M7", "type" => "radio", "label" => "Does the behavior occur when attention is diverted from the person?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M8", "type" => "radio", "label" => "Does the behavior occur when the person is denied access to a desired item or activity?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M9", "type" => "radio", "label" => "Does the behavior occur during a task that the person does not enjoy?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M10", "type" => "radio", "label" => "Does the behavior seem to be enjoyable to the person (self-stimulatory)?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M11", "type" => "radio", "label" => "Does the behavior occur to get a reaction from others?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
          { "id" => "M12", "type" => "radio", "label" => "Does the behavior occur to obtain food, toys, or a specific activity?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },

          # FAST Items
          { "id" => "F1", "type" => "radio", "label" => "Does the behavior occur when others are present, and does attention follow?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F2", "type" => "radio", "label" => "Does the behavior occur to avoid or escape a task, demand, or request?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F3", "type" => "radio", "label" => "Does the behavior produce a rewarding sensory effect without others?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F4", "type" => "radio", "label" => "Does the behavior remove an unpleasant sensation or reduce pain?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F5", "type" => "radio", "label" => "Does the behavior typically happen when the person is alone or unoccupied?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F6", "type" => "radio", "label" => "Does the behavior occur during transitions or when demands increase?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F7", "type" => "radio", "label" => "Does an adult typically react by giving attention or talking to the person?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
          { "id" => "F8", "type" => "radio", "label" => "Is the behavior reduced when a preferred item or activity is provided freely?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },

          # General Summary
          { "id" => "beh_summary", "type" => "textarea", "label" => "Clinical Function Hypotheses & Summary Notes", "required" => false, "visible" => true, "section" => "General" }
        ],
        "customSections" => [ "Incident Details", "ABC Tracking", "MASS", "FAST", "General" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form: Sensory Assessment ──────────────────────────────────────────────
    {
      form_name: "Sensory Assessment",
      form_type: :sensory,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-08-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-014",
          "revision" => "August 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          { "id" => "SEN-001", "type" => "radio", "label" => "Tactile Responsiveness (Sensory board, water, foam, lotion)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-002", "type" => "radio", "label" => "Response to Massage (Physical and facial expression reactions)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-003", "type" => "radio", "label" => "Texture Exploration (Rough vs. smooth fabric discs)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-004", "type" => "radio", "label" => "Sensory Bin Manipulation (Rice, dried beans, hydrogel beads)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-005", "type" => "radio", "label" => "Visual Tracking of Illuminated Toys (Fiber optic, glow wand)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-006", "type" => "radio", "label" => "Auditory Localization (Chimes, maracas, calming melodies)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-007", "type" => "radio", "label" => "Light Box Exploration (Geometric colored transparencies)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-008", "type" => "radio", "label" => "Bubble Play Eye Tracking & Pop Manding", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-009", "type" => "radio", "label" => "Vestibular Swing Tolerance (Slow linear swinging)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-010", "type" => "radio", "label" => "Deep Pressure Therapy (Weighted compression vest, peanut ball)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-011", "type" => "radio", "label" => "Trampoline Jumping (Proprioceptive rebound input)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
          { "id" => "SEN-012", "type" => "radio", "label" => "Joint Compression Sequence (Clinician physical protocol)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] }
        ],
        "customSections" => [ "Tactile", "Visual & Auditory", "Proprioception & Vestibular" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 4: Preference Assessment Data Sheet ──────────────────────────────
    {
      form_name: "Preference Assessment Data Sheet",
      form_type: :preference_assessment,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-08-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-013",
          "revision" => "August 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          { "id" => "pref_context", "type" => "dropdown", "label" => "Observation Context Setting", "required" => true, "visible" => true, "section" => "General", "options" => [ "Sensory Time (Station 2)", "Circle Time Group Instruction", "1:1 Table Task Play", "Arrival & Free Exploration", "Snack / Meal Routine" ] },
          { "id" => "pref_category", "type" => "dropdown", "label" => "Reinforcer Category Domain", "required" => true, "visible" => true, "section" => "General", "options" => [ "Visual (Tubes, Lights, Visual Timers)", "Auditory (Musical Blocks, Chimes, Singing)", "Tactile (Shaving Foam, Stretch Springs, Slime)", "Toys (Puzzles, Magnetic Apples, Shape Sorters)", "Movement (Crash Pad, Balance Ball, Swing)" ] },
          { "id" => "pref_item_name", "type" => "text", "label" => "Specific Stimulus Item Name", "required" => true, "visible" => true, "section" => "General" },
          { "id" => "pref_duration_seconds", "type" => "number", "label" => "Duration of Sustained Engagement (Seconds)", "required" => true, "visible" => true, "section" => "General" },
          { "id" => "pref_approach_frequency", "type" => "number", "label" => "Unprompted Approach / Reach Frequency Count", "required" => true, "visible" => true, "section" => "General" },
          { "id" => "pref_child_affect", "type" => "dropdown", "label" => "Observed Affect During Interaction", "required" => true, "visible" => true, "section" => "General", "options" => [ "Vocal Pleasure / Smiling / Laughter", "Calm Sustained Focus", "Indifferent / Neutral Contact", "Aversive Avoidance / Pushing Away", "Distress / Negative Vocalization" ] },
          { "id" => "pref_tier_ranking", "type" => "dropdown", "label" => "Evaluated Reinforcer Preference Tier", "required" => true, "visible" => true, "section" => "General", "options" => [ "Highest Tier (Primary Reinforcer - >80% Engagement)", "Moderate Tier (Secondary Reinforcer - 40-79% Engagement)", "Low Tier (Non-Preferred / Distractor - <40% Engagement)" ] },
          { "id" => "pref_delivery_guidelines", "type" => "textarea", "label" => "Clinical Delivery Protocol in 1:1 Therapy Trials", "required" => false, "visible" => true, "section" => "General" }
        ],
        "customSections" => [ "General", "Visual", "Auditory", "Tactile", "Toys", "Movement" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 5: Data Record Sheet (Task Analysis) ─────────────────────────────
    {
      form_name: "Data Record Sheet (Task Analysis)",
      form_type: :task_analysis,
      organization_name: "Melu'e Foundation",
      revision_number: 4,
      revision_date: Date.parse("2025-09-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-007-04",
          "revision" => "September 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          { "id" => "ta_target_goal", "type" => "dropdown", "label" => "Task Analysis Target Routine Goal", "required" => true, "visible" => true, "section" => "General", "options" => [ "Washing Hands Routine (7 Steps)", "Toileting - Urination Sequence (6 Steps)", "Toileting - Independent Request (4 Steps)", "Dressing - Putting on Shoes (5 Steps)", "Dressing - Putting on Pants (5 Steps)", "Packing School Bag Routine (5 Steps)", "Manding Sequence (Verbal / PECS) (4 Steps)" ] },
          { "id" => "ta_step_sequence", "type" => "number", "label" => "Step Sequence Number (1-10)", "required" => true, "visible" => true, "section" => "General" },
          { "id" => "ta_step_name", "type" => "text", "label" => "Behavioral Step Description", "required" => true, "visible" => true, "section" => "General" },
          { "id" => "ta_prompt_level", "type" => "dropdown", "label" => "Prompt Hierarchy Level Utilized", "required" => true, "visible" => true, "section" => "General", "options" => [ "FP — Full Physical Prompt", "PP — Partial Physical Prompt", "G — Gestural Prompt", "+ — Independent Execution" ] },
          { "id" => "ta_trial_status", "type" => "radio", "label" => "Step Trial Success / Fail Toggle", "required" => true, "visible" => true, "section" => "General", "options" => [ "+ (Independent Success)", "P (Prompted Success)", "- (Unsuccessful / Refusal)" ] },
          { "id" => "ta_trial_notes", "type" => "textarea", "label" => "Clinician Micro-Observations & Latency Stream", "required" => false, "visible" => true, "section" => "General" }
        ],
        "customSections" => [ "General" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 6: Social Skills Questionnaire ───────────────────────────────────
    {
      form_name: "Social Skills Questionnaire",
      form_type: :social_skills,
      organization_name: "Melu'e Foundation",
      revision_number: 1,
      revision_date: Date.parse("2025-08-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "MCTC-TRP-006-01",
          "revision" => "August 2025",
          "organization" => "Melu'e Foundation",
          "pages" => "Page 1 of 1"
        },
        "fields" => [
          # Section: Social Interaction
          { "id" => "soc_q1", "type" => "radio", "label" => "Initiates verbal greeting or wave to familiar teachers upon arrival", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q2", "type" => "radio", "label" => "Responds to peer approach with positive affect or shared attention", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q3", "type" => "radio", "label" => "Respects personal body boundary when sitting alongside peers", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },

          # Section: Communication
          { "id" => "soc_q4", "type" => "radio", "label" => "Uses vocal mand or communicative picture to ask adult for help", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q5", "type" => "radio", "label" => "Maintains eye contact during 1-to-1 conversational interactions (>2 secs)", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q6", "type" => "radio", "label" => "Answers simple social identity questions (What is your name? How old are you?)", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },

          # Section: Play & Leisure
          { "id" => "soc_q7", "type" => "radio", "label" => "Yields preferred toy to peer when prompt timer rings without tantrum", "required" => true, "visible" => true, "section" => "Play & Leisure", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q8", "type" => "radio", "label" => "Participates in simple turn-taking interactive play (Rolling ball, stacking)", "required" => true, "visible" => true, "section" => "Play & Leisure", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },

          # Section: Emotion Recognition & Safety
          { "id" => "soc_q9", "type" => "radio", "label" => "Discriminates happy vs. angry facial expressions on picture cards", "required" => true, "visible" => true, "section" => "General", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_q10", "type" => "radio", "label" => "Stops and freezes immediately upon hearing safety 'STOP' verbal cue", "required" => true, "visible" => true, "section" => "General", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
          { "id" => "soc_evaluator_summary", "type" => "textarea", "label" => "Evaluator Social Readiness Synthesis & Goal Bank Recommendations", "required" => true, "visible" => true, "section" => "General" }
        ],
        "customSections" => [ "Social Interaction", "Communication", "Play & Leisure", "General" ],
        "deletedSections" => [],
        "history" => []
      }
    },

    # ── Form 7: Individualized Behavior Intervention Plan (IUP) ──────────────
    {
      form_name: "Individualized Behavior Intervention Plan (IUP)",
      form_type: :iup,
      organization_name: "Melu'e Comprehensive Therapy Center",
      revision_number: 1,
      revision_date: Date.parse("2025-01-01"),
      is_default: true,
      field_schema: {
        "metadata" => {
          "form_id" => "IUP-2025/26",
          "revision" => "REV.-1 2025",
          "organization" => "Melu'e Comprehensive Therapy Center",
          "is_default" => true,
          "pages" => "Page 1 of 2"
        },
        "fields" => [
          # 1. Student Information
          { "id" => "iup_student_name", "type" => "text", "label" => "Student Full Name", "required" => true, "visible" => true, "section" => "1. Student Information" },
          { "id" => "iup_dob", "type" => "date", "label" => "Date of Birth", "required" => true, "visible" => true, "section" => "1. Student Information" },
          { "id" => "iup_clinical_diagnosis", "type" => "text", "label" => "Clinical Diagnosis & Severity Level", "required" => true, "visible" => true, "section" => "1. Student Information" },
          { "id" => "iup_plan_validity_dates", "type" => "text", "label" => "Plan Implementation Period (e.g., 2025-2026 Academic Cycle)", "required" => true, "visible" => true, "section" => "1. Student Information" },

          # 2. Assessment Summary
          { "id" => "iup_ablls_summary", "type" => "textarea", "label" => "ABLLS-R Skills Assessment Baseline Summary", "required" => true, "visible" => true, "section" => "2. Assessment Summary" },
          { "id" => "iup_mas_summary", "type" => "textarea", "label" => "Motivation Assessment Scale (MAS) Functional Ranking Summary", "required" => true, "visible" => true, "section" => "2. Assessment Summary" },
          { "id" => "iup_fast_summary", "type" => "textarea", "label" => "Functional Assessment Screening Tool (FAST) Behavioral Findings", "required" => true, "visible" => true, "section" => "2. Assessment Summary" },
          { "id" => "iup_preference_summary", "type" => "textarea", "label" => "Preference Assessment Hierarchy & High-Probability Reinforcers", "required" => true, "visible" => true, "section" => "2. Assessment Summary" },

          # 3. Reinforcement Strategies
          { "id" => "iup_reinforcement_schedule", "type" => "dropdown", "label" => "Reinforcement Schedule Structure", "required" => true, "visible" => true, "section" => "3. Reinforcement Strategies", "options" => [ "Continuous Reinforcement (FR-1)", "Fixed Ratio 2 (FR-2)", "Fixed Ratio 3 (FR-3)", "Variable Ratio 3 (VR-3)", "Differential Reinforcement of Alternative Behavior (DRA)" ] },
          { "id" => "iup_primary_reinforcers", "type" => "textarea", "label" => "Identified Primary & Secondary Reinforcers (Stretch spring, tube, bubbles, praise)", "required" => true, "visible" => true, "section" => "3. Reinforcement Strategies" },
          { "id" => "iup_reinforcement_protocol", "type" => "textarea", "label" => "Immediate Reinforcer Delivery Procedure & Token Economy", "required" => true, "visible" => true, "section" => "3. Reinforcement Strategies" },

          # 4. Consequence Strategies
          { "id" => "iup_extinction_procedures", "type" => "textarea", "label" => "Planned Extinction Procedures (Withholding tangible/attention upon target behavior)", "required" => true, "visible" => true, "section" => "4. Consequence Strategies" },
          { "id" => "iup_redirection_protocols", "type" => "textarea", "label" => "Active Redirection & Functional Communication Mand Prompts", "required" => true, "visible" => true, "section" => "4. Consequence Strategies" },
          { "id" => "iup_de_escalation_protocol", "type" => "textarea", "label" => "Calming Protocol & Transition to Quiet Space", "required" => true, "visible" => true, "section" => "4. Consequence Strategies" },

          # 5. Plan for Family Participation
          { "id" => "iup_parent_goal_1", "type" => "textarea", "label" => "Parent Goal 1: Home Implementation of Functional Manding", "required" => true, "visible" => true, "section" => "5. Family Participation" },
          { "id" => "iup_parent_goal_2", "type" => "textarea", "label" => "Parent Goal 2: Bedtime / Evening Routine Transition Tolerate", "required" => true, "visible" => true, "section" => "5. Family Participation" },
          { "id" => "iup_parent_goal_3", "type" => "textarea", "label" => "Parent Goal 3: Community Outing Safety & Hand Holding", "required" => true, "visible" => true, "section" => "5. Family Participation" },
          { "id" => "iup_family_mastery_criteria", "type" => "text", "label" => "Family Engagement Mastery Criterion (e.g., 80% fidelity over 4 weeks)", "required" => true, "visible" => true, "section" => "5. Family Participation" },

          # 6. Behavior Reduction Protocol
          { "id" => "iup_target_behavior_name", "type" => "text", "label" => "Target Problem Behavior for Reduction", "required" => true, "visible" => true, "section" => "6. Behavior Reduction" },
          { "id" => "iup_behavior_baseline_rate", "type" => "text", "label" => "Baseline Frequency / Duration (e.g., 14 screaming episodes/session)", "required" => true, "visible" => true, "section" => "6. Behavior Reduction" },
          { "id" => "iup_reduction_target_rate", "type" => "textarea", "label" => "Measurable Reduction Objective (<2 episodes/session across 3 consecutive weeks)", "required" => true, "visible" => true, "section" => "6. Behavior Reduction" },

          # 7. Replacement Behavior Goals
          { "id" => "iup_replacement_behavior_mand", "type" => "textarea", "label" => "Functional Replacement Mand (e.g., Using PECS or vocal 'Break' / 'Toy')", "required" => true, "visible" => true, "section" => "7. Replacement Behavior" },
          { "id" => "iup_replacement_mastery_criteria", "type" => "text", "label" => "Replacement Mand Mastery Criteria (e.g., 85% unprompted over 5 sessions)", "required" => true, "visible" => true, "section" => "7. Replacement Behavior" },

          # 8. Antecedent Manipulations
          { "id" => "iup_environmental_cues", "type" => "textarea", "label" => "Visual Schedules, Station Dividers & Lighting/Sensory Adjustments", "required" => true, "visible" => true, "section" => "8. Antecedent Manipulations" },
          { "id" => "iup_priming_procedures", "type" => "textarea", "label" => "Advance Priming, Transition Warning Timers & Visual First-Then Boards", "required" => true, "visible" => true, "section" => "8. Antecedent Manipulations" },

          # 9. Crisis Management Plan
          { "id" => "iup_behavioral_crisis_steps", "type" => "textarea", "label" => "Behavioral Crisis De-escalation Protocol (Neutral blocking, clear area, pad placement)", "required" => true, "visible" => true, "section" => "9. Crisis Management" },
          { "id" => "iup_medical_emergency_protocol", "type" => "textarea", "label" => "Medical Emergency Protocol (Medication administration, physician notification)", "required" => true, "visible" => true, "section" => "9. Crisis Management" },

          # 10. Plan for Coordination of Care
          { "id" => "iup_internal_care_coordination", "type" => "textarea", "label" => "Interdisciplinary Team Coordination (Lead Teacher, Coordinator, Program Director)", "required" => true, "visible" => true, "section" => "10. Coordination of Care" },
          { "id" => "iup_external_stakeholder_liaison", "type" => "textarea", "label" => "External Collaboration (Pediatrician, Neurologist, Future Inclusive School)", "required" => true, "visible" => true, "section" => "10. Coordination of Care" },

          # 11. Discharge Criteria & Titration Plan
          { "id" => "iup_titration_threshold_pullout", "type" => "text", "label" => "Titration Phase 1 Milestone Threshold", "required" => true, "visible" => true, "section" => "11. Discharge & Titration" },
          { "id" => "iup_titration_threshold_inclusive", "type" => "text", "label" => "Titration Phase 2 Full Inclusive School Transition Threshold", "required" => true, "visible" => true, "section" => "11. Discharge & Titration" },
          { "id" => "iup_discharge_criteria_narrative", "type" => "textarea", "label" => "Comprehensive Clinical Discharge Criteria & Generalization Milestones", "required" => true, "visible" => true, "section" => "11. Discharge & Titration" },

          # 12. Signatures
          { "id" => "iup_program_director_signature", "type" => "text", "label" => "Clinical Program Director Approval Signature & Date", "required" => true, "visible" => true, "section" => "12. Signatures" },
          { "id" => "iup_guardian_signature", "type" => "text", "label" => "Parent / Guardian Consent Signature & Date", "required" => true, "visible" => true, "section" => "12. Signatures" },
          { "id" => "iup_effective_approval_date", "type" => "date", "label" => "Formal Plan Approval Date", "required" => true, "visible" => true, "section" => "12. Signatures" }
        ],
        "customSections" => [
          "1. Student Information",
          "2. Assessment Summary",
          "3. Reinforcement Strategies",
          "4. Consequence Strategies",
          "5. Family Participation",
          "6. Behavior Reduction",
          "7. Replacement Behavior",
          "8. Antecedent Manipulations",
          "9. Crisis Management",
          "10. Coordination of Care",
          "11. Discharge & Titration",
          "12. Signatures"
        ],
        "deletedSections" => [],
        "history" => []
      }
    }
  ]

  # ── Canonical Frontend Form Aliases (Exact Name Matching) ─────────────────
  enrollment_cfg = form_configs_data.find { |f| f[:form_name] == "Enrollment Interview Form" }
  ablls_cfg      = form_configs_data.find { |f| f[:form_name] == "ABLLS-R Assessment Form" }
  pref_cfg       = form_configs_data.find { |f| f[:form_name] == "Preference Assessment Data Sheet" }
  iup_cfg        = form_configs_data.find { |f| f[:form_name] == "Individualized Behavior Intervention Plan (IUP)" }

  form_configs_data << {
    form_name: "Enrollment Wizard",
    form_type: :enrollment,
    organization_name: "Melu'e Foundation",
    revision_number: 1,
    revision_date: Date.parse("2024-07-01"),
    is_default: true,
    field_schema: enrollment_cfg[:field_schema]
  } if enrollment_cfg

  form_configs_data << {
    form_name: "ABLLS Assessment Form",
    form_type: :ablls,
    organization_name: "Melu'e Foundation",
    revision_number: 1,
    revision_date: Date.parse("2025-08-01"),
    is_default: true,
    field_schema: ablls_cfg[:field_schema]
  } if ablls_cfg

  form_configs_data << {
    form_name: "Preference Assessment",
    form_type: :preference_assessment,
    organization_name: "Melu'e Foundation",
    revision_number: 1,
    revision_date: Date.parse("2025-08-01"),
    is_default: true,
    field_schema: pref_cfg[:field_schema]
  } if pref_cfg

  form_configs_data << {
    form_name: "IUP Form",
    form_type: :iup,
    organization_name: "Melu'e Foundation",
    revision_number: 1,
    revision_date: Date.parse("2025-01-01"),
    is_default: true,
    field_schema: iup_cfg[:field_schema]
  } if iup_cfg

  form_configs_data.each do |fc_attrs|
    fc = FormConfiguration.find_or_initialize_by(form_name: fc_attrs[:form_name])
    fc.form_type         = fc_attrs[:form_type]
    fc.organization_name = fc_attrs[:organization_name]
    fc.revision_number   = fc_attrs[:revision_number]
    fc.revision_date     = fc_attrs[:revision_date]
    fc.is_default        = fc_attrs[:is_default]
    fc.field_schema      = fc_attrs[:field_schema]
    fc.save!

    field_count = fc_attrs[:field_schema]["fields"]&.size || 0
    form_id = fc_attrs[:field_schema].dig("metadata", "form_id") || "N/A"
    rev = fc_attrs[:field_schema].dig("metadata", "revision") || "N/A"
    puts "    ✓ Form: #{fc.form_name.ljust(44)} [#{form_id} | #{rev}] (#{field_count} fields)"
  end

  puts "\n--> Admin Configuration Summary:"
  puts "    Total Prompt Levels:          #{PromptLevel.count}"
  puts "    Total Therapy Stations:       #{TherapyStation.count}"
  puts "    Total Therapy Rooms:          #{TherapyRoom.count}"
  puts "    Total Session Blocks:         #{SessionBlockDefinition.count}"
  puts "    Total Form Configurations:    #{FormConfiguration.count}"
  puts ("=" * 80) + "\n"
end
