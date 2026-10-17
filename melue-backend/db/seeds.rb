# frozen_string_literal: true

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds Dispatcher
#
# Modular Seed Architecture:
#   1. db/seeds/01_credentials_and_users.rb
#      - Core RBAC Roles (7 standard roles per FR-016)
#      - Granular Permissions Matrix (Canonical + REST operations)
#      - Staff and Guardian User accounts with authentic clinical credentials
#
#   2. db/seeds/02_admin_configuration.rb
#      - Prompt levels with standard clinical color codes (FR-094, FR-142)
#      - Therapy stations and room infrastructure (Rooms 1A-1D, 2A-2D)
#      - Morning & Afternoon session block definitions and schedule configs (FR-150)
#      - Authentic clinical Form Configurations (MCTC-TRP series & IUP schema)
#
#   3. db/seeds/03_system_lookups_and_metadata.rb
#      - Sensory activities (SEN-001 through SEN-012) per FR-051b
#      - Authentic ABC dropdown antecedents, behaviors & consequences
#      - Five-category Preference Assessment Inventory
#      - Canonical Goal Bank domains and task analysis step templates
#      - Full 25-domain ABLLS-R hierarchy (A-Z) and milestone skill items
#
#   4. db/seeds/04_cohort_students_and_pipeline.rb
#      - Diverse cohort of 10 students spanning all clinical pipeline phases
#      - Completed assessment cycles, active IUPs, teacher assignments,
#        longitudinal historical therapy sessions, summaries, trials, and ABC logs
#
#   5. db/seeds/05_child_studentA_full_story.rb
#      - Student A (Adel) comprehensive clinical dossier profile
#      - Complete 6-week assessment cycle (ABLLS-R, MAS, FAST, Preference, Sensory)
#      - Active Individualized Behavior Intervention Plan (IUP)
#      - Authentic longitudinal ABC incident logs (15+ real timestamped incidents)
# ==============================================================================

puts "\n" + ("=" * 80)
puts "  MELUE FOUNDATION THERAPY MANAGEMENT SYSTEM — SEED DISPATCHER"
puts ("=" * 80) + "\n"

SEED_FILES = [
  "01_credentials_and_users.rb",
  "02_admin_configuration.rb",
  "03_system_lookups_and_metadata.rb",
  "04_cohort_students_and_pipeline.rb",
  "05_child_studentA_full_story.rb"
].freeze

SEED_FILES.each_with_index do |file_name, idx|
  file_path = Rails.root.join("db", "seeds", file_name)

  if File.exist?(file_path)
    puts "\n==> [STEP #{idx + 1}/5] Executing: db/seeds/#{file_name}"
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    load file_path

    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)
    puts "==> [STEP #{idx + 1}/5] Successfully finished db/seeds/#{file_name} (#{elapsed}s)"
  else
    puts "\n--> [STEP #{idx + 1}/5] Pending: db/seeds/#{file_name} (will run once generated)"
  end
end

puts "\n" + ("=" * 80)
puts "  SEED DISPATCH SEQUENCE COMPLETED"
puts ("=" * 80) + "\n"
