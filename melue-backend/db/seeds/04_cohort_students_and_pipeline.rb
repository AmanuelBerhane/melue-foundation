# frozen_string_literal: true

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File: db/seeds/04_cohort_students_and_pipeline.rb
#
# Clinical Cohort Seeding (SRS 3.2, 3.6, 3.7):
#   - Diverse cohort of 10 students spanning all clinical pipeline phases:
#       1. in_assessment (Amir Hassan, Tigist Bekele)
#       2. ready_for_iup (Saron Tekle, Biniam Hailu) with completed assessment cycles
#       3. active_therapy (Yonas Girma, Meron Haile, Abel Tadesse, Liya Belay)
#       4. completed_sessions (Natnael Worku, Hiwot Alemu)
#   - Completed Assessment Cycles (ABLLS-R, MAS, FAST, Preference, Sensory)
#   - Active IUPs and Standard Student Goals (STRICTLY standard goals, zero TA)
#   - Teacher-Student Station Assignments (Today + 5-day historical)
#   - Multi-day completed TherapySessions, SessionSummaries, and immutable Trials
#     (STRICTLY student_goal_step: nil on every single trial)
#   - Longitudinal Baseline Behavior Incidents (ABC Logs)
# ==============================================================================

ActiveRecord::Base.transaction do
  puts "\n================================================================================"
  puts "  STEP 4: COHORT STUDENTS, CLINICAL PIPELINE & HISTORICAL TRIAL STREAM"
  puts "================================================================================\n"

  # ----------------------------------------------------------------------------
  # 0. Lookup Required Admin & Taxonomy Records
  # ----------------------------------------------------------------------------
  puts "--> Fetching administrative references..."

  station1 = TherapyStation.find_by!(name: "Station 1")
  station2 = TherapyStation.find_by!(name: "Station 2")

  room_1a = TherapyRoom.find_by!(name: "Room 1A", therapy_station: station1)
  room_1b = TherapyRoom.find_by!(name: "Room 1B", therapy_station: station1)
  room_2a = TherapyRoom.find_by!(name: "Room 2A", therapy_station: station2)

  morning_block_a   = SessionBlockDefinition.find_by!(name: "Morning Block A")
  morning_block_b   = SessionBlockDefinition.find_by!(name: "Morning Block B")
  afternoon_block_a = SessionBlockDefinition.find_by!(name: "Afternoon Block A")

  teacher1 = StaffMember.joins(:user).find_by!(users: { email: "teacher1@melue.foundation" })
  teacher2 = StaffMember.joins(:user).find_by!(users: { email: "teacher2@melue.foundation" })
  teacher3 = StaffMember.joins(:user).find_by!(users: { email: "teacher3@melue.foundation" })

  coordinator_user  = User.find_by!(email: "coordinator@melue.foundation")
  coordinator_staff = StaffMember.find_by!(user: coordinator_user)
  director_user     = User.find_by!(email: "director@melue.foundation")

  prompt_fp = PromptLevel.find_by!(label: "FP")
  prompt_pp = PromptLevel.find_by!(label: "PP")
  prompt_g  = PromptLevel.find_by!(label: "G")
  prompt_ind = PromptLevel.find_by!(label: "+")

  puts "    ✓ Station 1 (Rooms 1A, 1B), Station 2 (Room 2A), blocks, teachers and prompt levels ready."

  # ----------------------------------------------------------------------------
  # Helper: Idempotent Student Builder
  # ----------------------------------------------------------------------------
  def self.seed_student(attributes, guardian_attributes)
    student = Student.find_or_initialize_by(
      first_name: attributes[:first_name],
      last_name:  attributes[:last_name]
    )

    student.assign_attributes(attributes)
    student.save!

    guardian = Guardian.find_or_create_by!(
      full_name: guardian_attributes[:full_name],
      phone:     guardian_attributes[:phone]
    )

    StudentGuardian.find_or_create_by!(
      student:  student,
      guardian: guardian
    ) do |sg|
      sg.relationship       = guardian_attributes[:relationship] || "Parent"
      sg.is_primary_contact = guardian_attributes.fetch(:is_primary_contact, true)
    end

    student
  end

  # ----------------------------------------------------------------------------
  # 1. Pipeline Stage 1: in_assessment (Ready for 6-week scoring)
  # ----------------------------------------------------------------------------
  puts "\n--> [1/4] Seeding Phase: 'in_assessment' students..."

  amir = seed_student(
    {
      first_name:            "Amir",
      last_name:             "Hassan",
      date_of_birth:         Date.parse("2019-07-22"),
      therapy_group:         "basic",
      program_type:          "regular",
      status:                "in_assessment",
      guardian_name:         "Fatuma Hassan",
      guardian_phone:        "+251 91 200 0001",
      guardian_email:        "fatuma.hassan@example.com",
      diagnosis:             "Suspected Autism Spectrum Disorder",
      assessment_started_at: 2.weeks.ago
    },
    {
      full_name:    "Fatuma Hassan",
      phone:        "+251 91 200 0001",
      email:        "fatuma.hassan@example.com",
      relationship: "Mother"
    }
  )

  tigist = seed_student(
    {
      first_name:            "Tigist",
      last_name:             "Bekele",
      date_of_birth:         Date.parse("2018-11-14"),
      therapy_group:         "basic",
      program_type:          "pulled_out",
      status:                "in_assessment",
      guardian_name:         "Almaz Bekele",
      guardian_phone:        "+251 91 200 0002",
      guardian_email:        "almaz.bekele@example.com",
      diagnosis:             "Global Developmental Delay",
      assessment_started_at: 3.weeks.ago
    },
    {
      full_name:    "Almaz Bekele",
      phone:        "+251 91 200 0002",
      email:        "almaz.bekele@example.com",
      relationship: "Mother"
    }
  )

  # Provision in-progress assessment cycles for in_assessment students
  [ amir, tigist ].each do |student|
    AssessmentCycle.find_or_create_by!(
      student:    student,
      started_on: student.assessment_started_at.to_date
    ) do |cycle|
      cycle.status = "in_progress"
    end
  end

  puts "    ✓ Amir Hassan and Tigist Bekele seeded in 'in_assessment'."

  # ----------------------------------------------------------------------------
  # 2. Pipeline Stage 2: ready_for_iup (Assessments completed, pending plan)
  # ----------------------------------------------------------------------------
  puts "\n--> [2/4] Seeding Phase: 'ready_for_iup' students and full assessment batteries..."

  saron = seed_student(
    {
      first_name:            "Saron",
      last_name:             "Tekle",
      date_of_birth:         Date.parse("2017-03-18"),
      therapy_group:         "basic",
      program_type:          "regular",
      status:                "ready_for_iup",
      guardian_name:         "Hiwot Tekle",
      guardian_phone:        "+251 91 200 0003",
      guardian_email:        "hiwot.tekle@example.com",
      diagnosis:             "ASD Level 1",
      enrolled_at:           8.weeks.ago,
      assessment_started_at: 6.weeks.ago
    },
    {
      full_name:    "Hiwot Tekle",
      phone:        "+251 91 200 0003",
      email:        "hiwot.tekle@example.com",
      relationship: "Mother"
    }
  )

  biniam = seed_student(
    {
      first_name:            "Biniam",
      last_name:             "Hailu",
      date_of_birth:         Date.parse("2013-09-05"),
      therapy_group:         "functional_living",
      program_type:          "regular",
      status:                "ready_for_iup",
      guardian_name:         "Mekdes Hailu",
      guardian_phone:        "+251 91 200 0004",
      guardian_email:        "mekdes.hailu@example.com",
      diagnosis:             "ASD Level 2",
      enrolled_at:           8.weeks.ago,
      assessment_started_at: 6.weeks.ago
    },
    {
      full_name:    "Mekdes Hailu",
      phone:        "+251 91 200 0004",
      email:        "mekdes.hailu@example.com",
      relationship: "Mother"
    }
  )

  # Provision full completed 5-part assessment battery for Saron and Biniam
  [ saron, biniam ].each do |student|
    cycle = AssessmentCycle.find_or_create_by!(
      student:    student,
      started_on: 6.weeks.ago.to_date
    ) do |c|
      c.completed_on = 4.days.ago.to_date
      c.status       = "complete"
    end

    # A. ABLLS Assessment & Milestone Responses
    ablls = AbllsAssessment.find_or_create_by!(
      assessment_cycle: cycle
    ) do |a|
      a.staff_member = coordinator_staff
      a.started_at   = 6.weeks.ago
      a.completed_at = 4.days.ago
      a.status       = "completed"
    end

    # Seed 15 representative ABLLS responses across domains
    sample_skills = AbllsSkillItem.order(:position).limit(15)
    sample_scores = %w[0 1 2 1 0 2 1 2 0 1 2 0 1 2 not_applicable]

    sample_skills.each_with_index do |item, idx|
      AbllsResponse.find_or_create_by!(
        ablls_assessment: ablls,
        ablls_skill_item: item
      ) do |r|
        r.score = sample_scores[idx % sample_scores.length]
      end
    end

    # B. Preference Assessment & Observations
    pref = PreferenceAssessment.find_or_create_by!(
      assessment_cycle: cycle
    ) do |p|
      p.status       = "submitted"
      p.submitted_at = 5.days.ago
    end

    pref_items = PreferenceInventoryItem.limit(4)
    pref_items.each_with_index do |inv_item, idx|
      PreferenceObservation.find_or_create_by!(
        preference_assessment:     pref,
        preference_inventory_item: inv_item,
        context:                   PreferenceObservation.contexts.keys[idx % 3]
      ) do |obs|
        obs.duration_seconds = 120 + (idx * 30)
        obs.frequency_count  = 3 + idx
        obs.approached       = true
        obs.tier             = %w[highest moderate moderate low][idx]
        obs.rank             = idx + 1
      end
    end

    # C. Sensory Assessment & Evaluation Records
    sensory = SensoryAssessment.find_or_create_by!(
      student: student
    ) do |s|
      s.status = "complete"
    end

    SensoryActivity.order(:activity_code).limit(4).each_with_index do |act, idx|
      SensoryAssessmentRecord.find_or_create_by!(
        sensory_assessment: sensory,
        sensory_activity:   act
      ) do |rec|
        rec.engagement_level  = idx.even? ? "Independent" : "Partial Physical Prompt"
        rec.response_reaction = idx.zero? ? "Enjoyed" : "Neutral"
        rec.remark            = "Consistent baseline response observed during evaluation."
      end
    end

    # D. FAST Assessment with Calculated Risk Indicators
    fast = FastAssessment.find_or_initialize_by(
      student:          student,
      assessment_cycle: cycle
    )
    fast.assign_attributes(
      teacher:      teacher1,
      status:       "completed",
      completed_at: 5.days.ago,
      responses:    {
        "1" => true,  "2" => false, "3" => true,  "4" => false,
        "5" => true,  "6" => true,  "7" => false, "8" => false,
        "9" => true,  "10" => false, "11" => true, "12" => false,
        "13" => false, "14" => true, "15" => false, "16" => false,
        "F1" => true, "F2" => true, "F3" => false, "F4" => false,
        "F5" => true, "F6" => false, "F7" => true, "F8" => true
      }
    )
    fast.calculate_risks!

    # E. MASS Assessment with Calculated Function Scores
    mass = MassAssessment.find_or_initialize_by(
      student:          student,
      assessment_cycle: cycle
    )
    mass.assign_attributes(
      teacher:      teacher1,
      status:       "completed",
      completed_at: 5.days.ago,
      responses:    {
        "1" => 4, "2" => 5, "3" => 2, "4" => 1,
        "5" => 5, "6" => 4, "7" => 1, "8" => 2,
        "9" => 4, "10" => 3, "11" => 2, "12" => 1,
        "13" => 3, "14" => 4, "15" => 2, "16" => 1,
        "17" => 2, "18" => 1, "19" => 2, "20" => 1,
        "M1" => 4, "M2" => 5, "M3" => 2, "M4" => 1,
        "M5" => 4, "M6" => 4, "M7" => 2, "M8" => 1,
        "M9" => 5, "M10" => 3, "M11" => 1, "M12" => 2
      }
    )
    mass.calculate_scores!
  end

  puts "    ✓ Saron Tekle and Biniam Hailu seeded in 'ready_for_iup' with full 5-part assessment records."

  # ----------------------------------------------------------------------------
  # 3. Pipeline Stage 3: active_therapy (Assigned stations, active IUPs & standard goals)
  # ----------------------------------------------------------------------------
  puts "\n--> [3/4] Seeding Phase: 'active_therapy' students, active IUPs and standard goals..."

  yonas = seed_student(
    {
      first_name:     "Yonas",
      last_name:      "Girma",
      date_of_birth:  Date.parse("2018-04-12"),
      therapy_group:  "basic",
      program_type:   "regular",
      status:         "active_therapy",
      guardian_name:  "Girma Wolde",
      guardian_phone: "+251 91 200 0005",
      guardian_email: "girma.wolde@example.com",
      diagnosis:      "Autism Spectrum Disorder"
    },
    { full_name: "Girma Wolde", phone: "+251 91 200 0005", email: "girma.wolde@example.com", relationship: "Father" }
  )

  meron = seed_student(
    {
      first_name:     "Meron",
      last_name:      "Haile",
      date_of_birth:  Date.parse("2017-09-05"),
      therapy_group:  "basic",
      program_type:   "regular",
      status:         "active_therapy",
      guardian_name:  "Haile Gebre",
      guardian_phone: "+251 91 200 0006",
      guardian_email: "haile.gebre@example.com",
      diagnosis:      "Autism Spectrum Disorder"
    },
    { full_name: "Haile Gebre", phone: "+251 91 200 0006", email: "haile.gebre@example.com", relationship: "Father" }
  )

  abel = seed_student(
    {
      first_name:     "Abel",
      last_name:      "Tadesse",
      date_of_birth:  Date.parse("2019-02-20"),
      therapy_group:  "basic",
      program_type:   "pulled_out",
      status:         "active_therapy",
      guardian_name:  "Tadesse Assefa",
      guardian_phone: "+251 91 200 0007",
      guardian_email: "tadesse.assefa@example.com",
      diagnosis:      "Developmental Delay & Social Communication Disorder"
    },
    { full_name: "Tadesse Assefa", phone: "+251 91 200 0007", email: "tadesse.assefa@example.com", relationship: "Father" }
  )

  liya = seed_student(
    {
      first_name:     "Liya",
      last_name:      "Belay",
      date_of_birth:  Date.parse("2016-11-30"),
      therapy_group:  "basic",
      program_type:   "regular",
      status:         "active_therapy",
      guardian_name:  "Belay Demisse",
      guardian_phone: "+251 91 200 0008",
      guardian_email: "belay.demisse@example.com",
      diagnosis:      "Autism Spectrum Disorder"
    },
    { full_name: "Belay Demisse", phone: "+251 91 200 0008", email: "belay.demisse@example.com", relationship: "Father" }
  )

  # Pipeline Stage 4: completed_sessions (Active therapy with rich multi-day trial history)
  natnael = seed_student(
    {
      first_name:     "Natnael",
      last_name:      "Worku",
      date_of_birth:  Date.parse("2013-06-15"),
      therapy_group:  "functional_living",
      program_type:   "regular",
      status:         "active_therapy",
      guardian_name:  "Worku Kassa",
      guardian_phone: "+251 91 200 0009",
      guardian_email: "worku.kassa@example.com",
      diagnosis:      "ASD Level 2 with Behavioral Challenges"
    },
    { full_name: "Worku Kassa", phone: "+251 91 200 0009", email: "worku.kassa@example.com", relationship: "Father" }
  )

  hiwot = seed_student(
    {
      first_name:     "Hiwot",
      last_name:      "Alemu",
      date_of_birth:  Date.parse("2014-08-08"),
      therapy_group:  "functional_living",
      program_type:   "pulled_out",
      status:         "active_therapy",
      guardian_name:  "Alemu Tsegaye",
      guardian_phone: "+251 91 200 0010",
      guardian_email: "alemu.tsegaye@example.com",
      diagnosis:      "ASD Level 2"
    },
    { full_name: "Alemu Tsegaye", phone: "+251 91 200 0010", email: "alemu.tsegaye@example.com", relationship: "Father" }
  )

  # Provision Active IUPs and 2 Standard Goals for Each Active Student
  # CRITICAL RESTRICTION: Every goal MUST have goal_type: "standard"
  active_students_config = [
    {
      student: yonas,
      station: station1,
      goals:   [ "Request preferred items using words", "Initiate greeting with peers" ]
    },
    {
      student: meron,
      station: station1,
      goals:   [ "Take turns in structured play", "Maintain pencil grip for 3 minutes" ]
    },
    {
      student: abel,
      station: station1,
      goals:   [ "Follow two-step verbal instructions", "Match identical objects" ]
    },
    {
      student: liya,
      station: station1,
      goals:   [ "Respond to greetings and goodbyes from others", "Maintain pencil grip for 3 minutes" ]
    },
    {
      student: natnael,
      station: station2,
      goals:   [ "Request preferred items using words", "Washing Hands" ]
    },
    {
      student: hiwot,
      station: station2,
      goals:   [ "Make eye contact during conversation", "Match identical objects" ]
    }
  ]

  student_goals_cache = {}

  active_students_config.each do |cfg|
    st = cfg[:student]

    iup = Iup.find_or_initialize_by(
      student: st,
      status:  "active"
    )
    iup.assign_attributes(
      created_by_user:   coordinator_user,
      finalized_by_user: director_user,
      finalized_on:      4.weeks.ago.to_date
    )
    iup.save!

    student_goals_cache[st.id] = []

    target_goals = cfg[:goals].map { |goal_title| Goal.find_by!(name: goal_title, goal_type: "standard") }

    # Clean up any non-target active goals on this IUP to respect max 2 goals per station
    iup.student_goals.where.not(goal_id: target_goals.map(&:id)).destroy_all

    target_goals.each do |g|
      sg = StudentGoal.find_or_initialize_by(
        student: st,
        iup:     iup,
        goal:    g
      )
      sg.assign_attributes(
        therapy_station:  cfg[:station],
        status:           "active",
        progress_percent: 35.0,
        clinical_note:    "Standard clinical goal actively tracked during 1-to-1 therapy sessions."
      )
      sg.save!

      student_goals_cache[st.id] << sg
    end
  end

  puts "    ✓ Active IUPs and 2 standard goals provisioned for all 6 active students."

  # ----------------------------------------------------------------------------
  # 4. Teacher-Student Station Assignments (SRS 3.7)
  # ----------------------------------------------------------------------------
  puts "\n--> Setting up current teacher-student station assignments..."

  today = Date.current

  # Teacher 1 -> Yonas & Meron | Morning Block A | Station 1 (Room 1A)
  [ yonas, meron ].each do |st|
    TeacherStudentAssignment.find_or_initialize_by(
      student:                   st,
      session_block_definition: morning_block_a,
      scheduled_date:           today
    ).tap do |tsa|
      tsa.teacher         = teacher1
      tsa.therapy_station = station1
      tsa.therapy_room    = room_1a
      tsa.status          = "scheduled"
      tsa.save!
    end
  end

  # Teacher 2 -> Abel & Liya | Morning Block B | Station 1 (Room 1B)
  [ abel, liya ].each do |st|
    TeacherStudentAssignment.find_or_initialize_by(
      student:                   st,
      session_block_definition: morning_block_b,
      scheduled_date:           today
    ).tap do |tsa|
      tsa.teacher         = teacher2
      tsa.therapy_station = station1
      tsa.therapy_room    = room_1b
      tsa.status          = "scheduled"
      tsa.save!
    end
  end

  # Teacher 3 -> Natnael & Hiwot | Afternoon Block A | Station 2 (Room 2A) (Today's Assignment)
  [ natnael, hiwot ].each do |st|
    TeacherStudentAssignment.find_or_initialize_by(
      student:                   st,
      session_block_definition: afternoon_block_a,
      scheduled_date:           today
    ).tap do |tsa|
      tsa.teacher         = teacher3
      tsa.therapy_station = station2
      tsa.therapy_room    = room_2a
      tsa.status          = "scheduled"
      tsa.save!
    end
  end

  puts "    ✓ Today's teacher-student assignments established across Stations 1 & 2."

  # ----------------------------------------------------------------------------
  # 5. Historical Sessions, Summaries & Standard Trials (Natnael & Hiwot)
  # ----------------------------------------------------------------------------
  puts "\n--> Seeding 5 historical completed sessions, coordinator reviews and standard trials..."

  # Compute past 5 weekdays
  past_weekdays = (1..10).map { |n| n.days.ago.to_date }
                        .reject { |d| d.saturday? || d.sunday? }
                        .first(5)
                        .reverse

  past_weekdays.each_with_index do |hist_date, day_idx|
    # A. Historical Teacher-Student Assignments
    natnael_tsa = TeacherStudentAssignment.find_or_initialize_by(
      student:                   natnael,
      session_block_definition: afternoon_block_a,
      scheduled_date:           hist_date
    ).tap do |tsa|
      tsa.teacher         = teacher3
      tsa.therapy_station = station2
      tsa.therapy_room    = room_2a
      tsa.status          = "completed"
      tsa.save!
    end

    hiwot_tsa = TeacherStudentAssignment.find_or_initialize_by(
      student:                   hiwot,
      session_block_definition: afternoon_block_a,
      scheduled_date:           hist_date
    ).tap do |tsa|
      tsa.teacher         = teacher3
      tsa.therapy_station = station2
      tsa.therapy_room    = room_2a
      tsa.status          = "completed"
      tsa.save!
    end

    # B. Completed Therapy Session
    session_start = hist_date.to_time.change(hour: 13, min: 30)
    session_end   = hist_date.to_time.change(hour: 15, min: 0)

    # Use find_by or initialize without creating incomplete records
    session = TherapySession.where(
      teacher:                  teacher3,
      session_block_definition: afternoon_block_a,
      therapy_station:          station2,
      therapy_room:             room_2a
    ).where("started_at >= ? AND started_at <= ?", hist_date.beginning_of_day, hist_date.end_of_day).first

    if session.nil?
      session = TherapySession.new(
        teacher:                  teacher3,
        session_block_definition: afternoon_block_a,
        therapy_station:          station2,
        therapy_room:             room_2a,
        started_at:               session_start,
        ended_at:                 session_end,
        status:                   "in_progress" # start as in_progress to add participants
      )
      session.save!(validate: false)

      p1 = SessionParticipant.create!(
        therapy_session:               session,
        student:                       natnael,
        teacher_student_assignment:    natnael_tsa,
        card_position:                 :active,
        current_focus_student_goal:    student_goals_cache[natnael.id].first
      )

      p2 = SessionParticipant.create!(
        therapy_session:               session,
        student:                       hiwot,
        teacher_student_assignment:    hiwot_tsa,
        card_position:                 :secondary,
        current_focus_student_goal:    student_goals_cache[hiwot.id].first
      )

      session.update!(status: "completed")
    else
      p1 = SessionParticipant.find_or_create_by!(
        therapy_session: session,
        student:         natnael
      ) do |sp|
        sp.teacher_student_assignment = natnael_tsa
        sp.card_position              = :active
        sp.current_focus_student_goal = student_goals_cache[natnael.id].first
      end

      p2 = SessionParticipant.find_or_create_by!(
        therapy_session: session,
        student:         hiwot
      ) do |sp|
        sp.teacher_student_assignment = hiwot_tsa
        sp.card_position              = :secondary
        sp.current_focus_student_goal = student_goals_cache[hiwot.id].first
      end
    end

    # C. Reviewed Session Summary
    summary = SessionSummary.find_or_initialize_by(therapy_session: session)
    summary.assign_attributes(
      status:             "reviewed",
      submitted_at:       session_end + 10.minutes,
      reviewed_by_user:   coordinator_user,
      reviewed_at:        session_end + 45.minutes,
      qualitative_notes:  "Session on #{hist_date.strftime('%B %d')}: Natnael showed strong verbal response during functional living routines. Hiwot maintained focus with partial physical prompting."
    )
    summary.save!

    # D. Standard Trials
    # CRITICAL RESTRICTION: Every trial must have student_goal_step: nil
    [
      { participant: p1, goals: student_goals_cache[natnael.id] },
      { participant: p2, goals: student_goals_cache[hiwot.id] }
    ].each do |part_config|
      part = part_config[:participant]
      part_goals = part_config[:goals]

      # Generate 8 realistic trials per participant
      8.times do |t_idx|
        goal = part_goals[t_idx % part_goals.length]
        event_id = "trial-seed-#{session.id}-#{part.id}-#{t_idx + 1}"

        next if Trial.exists?(client_event_id: event_id)

        prompt = case t_idx
        when 0..1 then prompt_fp
        when 2..3 then prompt_pp
        when 4..5 then prompt_g
        else prompt_ind
        end

        outcome = case t_idx
        when 0..1 then (t_idx.zero? ? "no_response" : "incorrect")
        when 2..4 then "correct"
        else (t_idx == 5 ? "incorrect" : "correct")
        end

        trial_time = session_start + (10 + t_idx * 8).minutes

        Trial.create!(
          client_event_id:       event_id,
          therapy_session:       session,
          session_participant:   part,
          student_goal:          goal,
          student_goal_step:     nil, # STRICTLY NIL per instruction
          prompt_level:          prompt,
          prompt_label_snapshot: prompt.label,
          outcome:               outcome,
          logged_at:             trial_time
        )
      end
    end
  end

  puts "    ✓ 5 historical completed sessions, participants, summaries and 80 immutable standard trials created."

  # ----------------------------------------------------------------------------
  # 6. Longitudinal Baseline Behavior Incidents (ABC Logs) (SRS 3.6.3)
  # ----------------------------------------------------------------------------
  puts "\n--> Seeding baseline ABC behavior incident logs across the past 10 days..."

  incident_blueprints = [
    # Yonas Girma (Station 1 - Room 1A)
    {
      student:             yonas,
      staff_member:        teacher1,
      behavior_name:       "Flopping",
      behavior_definition: "Throwing self on the floor suddenly during transitions or instructions",
      antecedent:          "Demand placed / Instruction given",
      consequence:         "Verbal redirection / Prompting",
      frequency:           :frequently,
      intensity:           :moderate,
      category:            :flopping,
      location:            "Room 1A",
      days_ago:            8,
      hour:                9,
      notes:               "Flopped upon instruction to sit at table for fine motor task."
    },
    {
      student:             yonas,
      staff_member:        teacher1,
      behavior_name:       "Unable to remain seated",
      behavior_definition: "Repeatedly standing up or leaning in seated position within a designated time frame",
      antecedent:          "Transition between activities",
      consequence:         "Differential reinforcement",
      frequency:           :constantly,
      intensity:           :mild,
      category:            :hyperactivity,
      location:            "Room 1A",
      days_ago:            6,
      hour:                10,
      notes:               "Stood up 4 times in 5 minutes during structured pencil grip activity."
    },
    {
      student:             yonas,
      staff_member:        teacher1,
      behavior_name:       "Screaming",
      behavior_definition: "Producing a loud high-pitched sound that can be heard across the room",
      antecedent:          "Attention removed / redirected",
      consequence:         "Planned ignoring",
      frequency:           :occasionally,
      intensity:           :moderate,
      category:            :making_noises,
      location:            "Sensory Room",
      days_ago:            3,
      hour:                11,
      notes:               "Screamed when peer received token reinforcer first."
    },

    # Natnael Worku (Station 2 - Room 2A)
    {
      student:             natnael,
      staff_member:        teacher3,
      behavior_name:       "Elopement",
      behavior_definition: "Running or wandering away from supervision (moving away at least 5 feet)",
      antecedent:          "Transition between activities",
      consequence:         "Verbal redirection / Prompting",
      frequency:           :occasionally,
      intensity:           :severe,
      category:            :elopement,
      location:            "Room 2A Hallway",
      days_ago:            9,
      hour:                14,
      notes:               "Attempted to bolt toward the outer gate during transition from hand washing."
    },
    {
      student:             natnael,
      staff_member:        teacher3,
      behavior_name:       "Flopping",
      behavior_definition: "Throwing self on the floor suddenly",
      antecedent:          "Demand placed / Instruction given",
      consequence:         "Provided sensory break",
      frequency:           :frequently,
      intensity:           :moderate,
      category:            :flopping,
      location:            "Room 2A",
      days_ago:            5,
      hour:                14,
      notes:               "Refused step 3 of hand washing; dropped to floor and covered ears."
    },
    {
      student:             natnael,
      staff_member:        teacher3,
      behavior_name:       "Biting others",
      behavior_definition: "Placing teeth on another person's hand and/or abdomen and applying pressure",
      antecedent:          "Denied access to item/activity",
      consequence:         "Temporary removal of task",
      frequency:           :rarely,
      intensity:           :severe,
      category:            :safety_concerns,
      location:            "Room 2A",
      days_ago:            2,
      hour:                14,
      notes:               "Lunged towards assistant's arm when sensory ball was put away. Blocked safely."
    },

    # Hiwot Alemu (Station 2 - Room 2A)
    {
      student:             hiwot,
      staff_member:        teacher3,
      behavior_name:       "Unable to remain seated",
      behavior_definition: "Repeatedly standing up or leaning in seated position within a designated time frame",
      antecedent:          "Sensory overload / Loud noise",
      consequence:         "Provided sensory break",
      frequency:           :frequently,
      intensity:           :mild,
      category:            :hyperactivity,
      location:            "Room 2A",
      days_ago:            7,
      hour:                14,
      notes:               "Agitated by construction noise outside; stood up and rocked."
    },
    {
      student:             hiwot,
      staff_member:        teacher3,
      behavior_name:       "Screaming",
      behavior_definition: "Producing a loud high-pitched sound that can be heard across the room",
      antecedent:          "Denied access to item/activity",
      consequence:         "Differential reinforcement",
      frequency:           :occasionally,
      intensity:           :moderate,
      category:            :making_noises,
      location:            "Room 2A",
      days_ago:            4,
      hour:                14,
      notes:               "High pitched vocal protest when preferred visual timer was reset."
    }
  ]

  incident_blueprints.each do |blueprint|
    occ_date = blueprint[:days_ago].days.ago.to_date
    occ_time = occ_date.to_time.change(hour: blueprint[:hour], min: 25)

    incident = BehaviorIncident.find_or_initialize_by(
      student:         blueprint[:student],
      behavior_name:   blueprint[:behavior_name],
      occurred_at:     occ_time
    )

    incident.assign_attributes(
      staff_member:        blueprint[:staff_member],
      behavior_definition: blueprint[:behavior_definition],
      antecedent:          blueprint[:antecedent],
      consequence:         blueprint[:consequence],
      frequency:           blueprint[:frequency],
      intensity:           blueprint[:intensity],
      category:            blueprint[:category],
      location:            blueprint[:location],
      additional_notes:    blueprint[:notes]
    )
    incident.save!
  end

  puts "    ✓ Longitudinal ABC incidents seeded for Yonas, Natnael, and Hiwot."

  puts "\n" + ("=" * 80)
  puts "  STEP 4 COMPLETE: 10 Cohort Students, Pipeline Stages & Historical Data Seeded"
  puts ("=" * 80) + "\n"
end
