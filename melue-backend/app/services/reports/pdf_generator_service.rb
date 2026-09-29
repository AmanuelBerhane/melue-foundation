# frozen_string_literal: true

module Reports
  # Generates standard-compliant, self-contained PDF documents for Melue Foundation (FR-136, FR-156a).
  # Produces pure %PDF-1.4 binary documents without external dependencies.
  # Sections:
  #   1. Student Demographics & Clinical Placement
  #   2. Six-Week Clinical Assessment Summary
  #   3. IUP Goals & Mastery Progression (all goals, paginated)
  #   4. Therapy Attendance & Clinical Trial Metrics
  #   5. Behavior Monitoring & ABC Incidents
  #   6. Confidential Internal Clinical Notes (Director only)
  #   7. Clinical Review & Governance Sign-Off
  class PdfGeneratorService < ApplicationService
    PAGE_WIDTH    = 612  # Standard US Letter (72 pt/inch)
    PAGE_HEIGHT   = 792
    LEFT_MARGIN   = 40
    RIGHT_MARGIN  = 572
    TOP_MARGIN    = 750
    BOTTOM_MARGIN = 60   # Reserve for footer

    def initialize(data:, report_type: "student_progress")
      @data        = data
      @report_type = report_type
    end

    def call
      success(generate_pdf)
    rescue StandardError => e
      failure(e.message)
    end

    private

    # ─────────────────────────────────────────────────────────
    # Top-level builder: accumulates sections into pages
    # ─────────────────────────────────────────────────────────

    def generate_pdf
      @pages          = []
      @current_cmds   = []
      @page_num       = 1
      @y              = TOP_MARGIN

      # Page 1 header
      emit render_document_header
      @y -= 90

      # Section 1
      emit_section { render_demographics_section(extract_student_info) }

      # Section 2
      emit_section { render_assessment_section }

      # Section 3 — Goals (all of them)
      emit_section { render_goals_section }

      # Section 4 — Sessions & Trials
      emit_section { render_therapy_performance_section }

      # Section 5 — Behavior
      emit_section { render_behavior_summary_section }

      # Section 6 — Internal Notes (confidential)
      emit_section { render_internal_notes_section }

      # Section 7 — Signatures
      emit_section { render_signatures_section }

      finish_page
      assemble_pdf_document(@pages)
    end

    # Emits a section, inserting a page break if the section won't fit
    def emit_section(&block)
      cmds, height_used = block.call
      if @y - height_used < BOTTOM_MARGIN
        finish_page
        new_page
      end
      emit cmds
      @y -= height_used
    end

    def emit(cmd_str)
      @current_cmds << cmd_str
    end

    def finish_page
      @pages << @current_cmds.join("\n")
      @current_cmds = []
    end

    def new_page
      @page_num += 1
      @y = TOP_MARGIN
      emit render_page_continuation_header
      @y -= 50
    end

    # ─────────────────────────────────────────────────────────
    # Page headers
    # ─────────────────────────────────────────────────────────

    def render_document_header
      cmds = []
      cmds << "0.95 0.95 0.98 rg"
      cmds << "#{LEFT_MARGIN} 730 #{RIGHT_MARGIN - LEFT_MARGIN} 50 re f"
      cmds << "0.2 0.3 0.6 RG 1.5 w"
      cmds << "#{LEFT_MARGIN} 730 #{RIGHT_MARGIN - LEFT_MARGIN} 50 re S"
      cmds << "BT /F2 13 Tf 0.1 0.2 0.5 rg #{LEFT_MARGIN + 12} 758 Td (MELUE FOUNDATION - CENTER FOR AUTISM) Tj ET"
      cmds << "BT /F1 8.5 Tf 0.3 0.3 0.3 rg #{LEFT_MARGIN + 12} 744 Td (Form ID: MCTC-TRP-015 | Rev: August 2025 | Comprehensive Student Progress Report) Tj ET"
      cmds << "0.85 0.15 0.15 rg"
      cmds << "BT /F2 8 Tf 430 758 Td (STRICTLY CONFIDENTIAL) Tj ET"
      cmds << "BT /F1 7.5 Tf 0.4 0.4 0.4 rg 430 744 Td (Clinical & Oversight Record) Tj ET"
      cmds << "0.7 0.7 0.7 RG 0.5 w #{LEFT_MARGIN} 720 m #{RIGHT_MARGIN} 720 l S"
      cmds.join("\n")
    end

    def render_page_continuation_header
      total_est = @pages.size + 1
      cmds = []
      cmds << "0.8 0.8 0.8 RG 0.5 w #{LEFT_MARGIN} 765 m #{RIGHT_MARGIN} 765 l S"
      cmds << "BT /F1 8 Tf 0.4 0.4 0.4 rg #{LEFT_MARGIN} 770 Td (Melue Foundation - Student Progress Report | Page #{@page_num} | Continued) Tj ET"
      cmds.join("\n")
    end

    def render_page_footer(y)
      "BT /F1 7 Tf 0.5 0.5 0.5 rg #{LEFT_MARGIN} #{y} Td (CONFIDENTIAL — Melue Foundation Therapy Management System | Report generated #{Date.today.strftime('%B %d, %Y')}) Tj ET"
    end

    # ─────────────────────────────────────────────────────────
    # Section 1 — Demographics
    # ─────────────────────────────────────────────────────────

    def render_demographics_section(student)
      cmds = []
      y    = @y

      cmds << section_header("1. STUDENT DEMOGRAPHICS & CLINICAL PLACEMENT", y)
      y -= 16

      cmds << "0.96 0.97 0.99 rg #{LEFT_MARGIN} #{y - 54} #{RIGHT_MARGIN - LEFT_MARGIN} 58 re f"
      cmds << "0.8 0.85 0.9 RG 0.8 w #{LEFT_MARGIN} #{y - 54} #{RIGHT_MARGIN - LEFT_MARGIN} 58 re S"

      name      = student[:name] || "Student"
      dob       = student[:dob]  || "N/A"
      age       = student[:age]  ? "#{student[:age]} yrs" : "N/A"
      diagnosis = student[:diagnosis] || "Autism Spectrum Disorder"
      prog      = (student[:program_type] || "Regular").to_s.titleize
      group     = (student[:therapy_group] || "Basic Therapy").to_s.titleize
      status    = (student[:status] || "Active Therapy").to_s.titleize
      guardian  = student[:guardian] || "N/A"
      enroll    = student[:enrollment_date] || "N/A"

      yt = y - 14
      cmds << field_row(yt, "Student Name:", name, "Diagnosis:", diagnosis)
      yt -= 14
      cmds << field_row(yt, "Date of Birth:", "#{dob} (Age: #{age})", "Program:", "#{prog} / #{group}")
      yt -= 14
      cmds << field_row(yt, "Status:", status, "Guardian:", guardian)
      yt -= 14
      cmds << field_row(yt, "Enrollment Date:", enroll, "Report Date:", Date.today.strftime("%B %d, %Y"))

      [ cmds.join("\n"), 80 ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 2 — Assessment summary
    # ─────────────────────────────────────────────────────────

    def render_assessment_section
      cmds  = []
      y     = @y

      cmds << section_header("2. SIX-WEEK CLINICAL ASSESSMENT SUMMARY", y)
      y -= 16

      assessment = @data[:assessment_summary] || {}
      ablls      = assessment[:ablls] || {}
      pref       = assessment[:preference] || {}
      sensory    = assessment[:sensory]
      cycles     = assessment[:cycles_count] || 0

      ablls_pct    = ablls[:progress_percentage] ? "#{ablls[:progress_percentage]}%" : "Not started"
      mastered     = ablls[:mastered_count]    || 0
      emerging     = ablls[:emerging_count]    || 0
      top_pref     = pref[:top_preferences]&.first ? pref[:top_preferences].first[:item_name] : "N/A"
      sensory_stat = sensory ? "#{sensory[:activities_assessed]} activities" : "Not completed"

      cmds << "0.98 0.98 0.98 rg #{LEFT_MARGIN} #{y - 50} #{RIGHT_MARGIN - LEFT_MARGIN} 54 re f"
      cmds << "0.85 0.85 0.85 RG 0.5 w #{LEFT_MARGIN} #{y - 50} #{RIGHT_MARGIN - LEFT_MARGIN} 54 re S"

      yt = y - 14
      cmds << "BT /F2 9 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{yt} Td (Assessment Cycles Completed:) Tj /F1 9 Tf 160 0 Td (#{cycles}) Tj ET"
      yt -= 13
      cmds << "BT /F2 9 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{yt} Td (ABLLS-R Skills Assessment:) Tj /F1 9 Tf 160 0 Td (#{escape(ablls_pct)} | Mastered: #{mastered}, Emerging: #{emerging}) Tj ET"
      yt -= 13
      cmds << "BT /F2 9 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{yt} Td (Primary Reinforcer:) Tj /F1 9 Tf 160 0 Td (#{escape(top_pref)}) Tj ET"
      yt -= 13
      cmds << "BT /F2 9 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{yt} Td (Sensory Assessment:) Tj /F1 9 Tf 160 0 Td (#{escape(sensory_stat)}) Tj ET"

      [ cmds.join("\n"), 74 ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 3 — Goals (all, paginating table rows)
    # ─────────────────────────────────────────────────────────

    def render_goals_section
      cmds   = []
      y      = @y
      height = 0

      cmds << section_header("3. IUP GOALS & MASTERY PROGRESSION", y)
      y -= 14; height += 14

      # Table header row
      cmds << "0.9 0.93 0.98 rg #{LEFT_MARGIN} #{y - 14} #{RIGHT_MARGIN - LEFT_MARGIN} 16 re f"
      cmds << "0.6 0.7 0.85 RG 0.8 w #{LEFT_MARGIN} #{y - 14} #{RIGHT_MARGIN - LEFT_MARGIN} 16 re S"
      cmds << "BT /F2 7.5 Tf 0.1 0.2 0.4 rg"
      cmds << "#{LEFT_MARGIN + 6} #{y - 10} Td (GOAL) Tj"
      cmds << "#{LEFT_MARGIN + 190} #{y - 10} Td (DOMAIN) Tj"
      cmds << "#{LEFT_MARGIN + 290} #{y - 10} Td (STATION) Tj"
      cmds << "#{LEFT_MARGIN + 375} #{y - 10} Td (PROGRESS) Tj"
      cmds << "#{LEFT_MARGIN + 435} #{y - 10} Td (STATUS) Tj"
      cmds << "#{LEFT_MARGIN + 490} #{y - 10} Td (MASTERY) Tj"
      cmds << "ET"
      y -= 16; height += 16

      goals = extract_goals
      goals.each_with_index do |goal, idx|
        # Page break inside section if needed
        if y - 15 < BOTTOM_MARGIN
          finish_page
          new_page
          y      = @y
          height = 0
          # Re-emit mini header on new page
          cmds << render_page_continuation_header
          y -= 50; height += 50
        end

        row_bg = idx.even? ? "1 1 1 rg" : "0.97 0.98 1.0 rg"
        cmds << "#{row_bg} #{LEFT_MARGIN} #{y - 14} #{RIGHT_MARGIN - LEFT_MARGIN} 15 re f"
        cmds << "0.85 0.88 0.92 RG 0.4 w #{LEFT_MARGIN} #{y - 14} #{RIGHT_MARGIN - LEFT_MARGIN} 15 re S"

        g_name    = truncate(goal[:name]    || "Goal",      28)
        g_domain  = truncate(goal[:domain]  || "General",   14)
        g_station = truncate(goal[:station] || "N/A",       12)
        g_prog    = "#{goal[:progress] || 0}%"
        g_stat    = truncate((goal[:status] || "Active").to_s.titleize, 10)
        g_mastery = goal[:mastery_status] ? truncate(goal[:mastery_status].to_s.titleize, 12) : "—"

        cmds << "BT /F1 7.5 Tf 0.1 0.1 0.1 rg"
        cmds << "#{LEFT_MARGIN + 6} #{y - 11} Td (#{escape(g_name)}) Tj"
        cmds << "#{LEFT_MARGIN + 190} #{y - 11} Td (#{escape(g_domain)}) Tj"
        cmds << "#{LEFT_MARGIN + 290} #{y - 11} Td (#{escape(g_station)}) Tj"
        cmds << "#{LEFT_MARGIN + 375} #{y - 11} Td (#{escape(g_prog)}) Tj"
        cmds << "#{LEFT_MARGIN + 435} #{y - 11} Td (#{escape(g_stat)}) Tj"
        cmds << "#{LEFT_MARGIN + 490} #{y - 11} Td (#{escape(g_mastery)}) Tj"
        cmds << "ET"
        y -= 15; height += 15
      end

      if goals.empty?
        cmds << "BT /F1 9 Tf 0.4 0.4 0.4 rg #{LEFT_MARGIN + 6} #{y - 12} Td (No goals currently assigned.) Tj ET"
        height += 18
      end

      height += 10
      [ cmds.join("\n"), height ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 4 — Therapy performance
    # ─────────────────────────────────────────────────────────

    def render_therapy_performance_section
      cmds = []
      y    = @y

      cmds << section_header("4. THERAPY ATTENDANCE & CLINICAL TRIAL METRICS", y)
      y -= 16

      sessions   = @data[:session_history] || {}
      trials     = @data[:trial_performance] || {}

      total_sess   = sessions[:total_sessions]     || 0
      comp_sess    = sessions[:completed_sessions]  || 0
      attend_rate  = sessions[:attendance_rate]     || 0.0
      total_trials = trials[:total_trials]          || 0
      indep_pct    = trials[:overall_independence_percent] || 0.0

      cmds << "0.97 0.98 0.99 rg #{LEFT_MARGIN} #{y - 52} #{RIGHT_MARGIN - LEFT_MARGIN} 56 re f"
      cmds << "0.8 0.85 0.9 RG 0.6 w #{LEFT_MARGIN} #{y - 52} #{RIGHT_MARGIN - LEFT_MARGIN} 56 re S"

      yt = y - 14
      cmds << field_row(yt, "Total Sessions Attended:", "#{total_sess} sessions", "Total Clinical Trials:", "#{total_trials} trials")
      yt -= 13
      cmds << field_row(yt, "Sessions Completed:", "#{comp_sess} (#{attend_rate}%)", "Independence Rate (+):", "#{indep_pct}%")
      yt -= 13

      # Prompt breakdown (up to 4 rows)
      breakdown = trials[:prompt_breakdown] || []
      breakdown.first(4).each do |item|
        cmds << "BT /F2 8.5 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{yt} Td (#{escape(item[:prompt_level] || 'Unknown')}:) Tj /F1 8.5 Tf 120 0 Td (#{item[:count]} trials \\(#{item[:percentage]}%\\)) Tj ET"
        yt -= 12
      end

      [ cmds.join("\n"), 76 ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 5 — Behavior incidents
    # ─────────────────────────────────────────────────────────

    def render_behavior_summary_section
      cmds   = []
      y      = @y
      height = 0

      cmds << section_header("5. BEHAVIOR MONITORING & ABC INCIDENTS", y)
      y -= 16; height += 16

      incidents_data   = @data[:behavior_incident_trends] || {}
      total_inc        = incidents_data.is_a?(Hash) ? (incidents_data[:total_incidents] || 0) : 0
      recent_incidents = incidents_data.is_a?(Hash) ? (incidents_data[:recent_incidents] || []) : []

      cmds << "0.98 0.98 0.98 rg #{LEFT_MARGIN} #{y - 26} #{RIGHT_MARGIN - LEFT_MARGIN} 28 re f"
      cmds << "0.85 0.85 0.85 RG 0.5 w #{LEFT_MARGIN} #{y - 26} #{RIGHT_MARGIN - LEFT_MARGIN} 28 re S"
      cmds << "BT /F1 8.5 Tf 0.2 0.2 0.2 rg #{LEFT_MARGIN + 10} #{y - 14} Td (Total Behavior Incidents Logged: #{total_inc}) Tj ET"
      y -= 26; height += 26

      if recent_incidents.any?
        cmds << "BT /F2 8 Tf 0.1 0.2 0.4 rg #{LEFT_MARGIN} #{y - 10} Td (Recent Incidents:) Tj ET"
        y -= 14; height += 14
        recent_incidents.first(5).each do |inc|
          behavior = truncate(inc[:behavior_name] || "Behavior", 25)
          occurred = inc[:occurred_at] ? inc[:occurred_at].strftime("%b %d, %Y") : "N/A"
          cmds << "BT /F1 8 Tf 0.15 0.15 0.15 rg #{LEFT_MARGIN + 10} #{y - 10} Td (#{occurred}: #{escape(behavior)} | Intensity: #{escape(inc[:intensity] || 'N/A')}) Tj ET"
          y -= 12; height += 12
        end
      end

      height += 6
      [ cmds.join("\n"), height ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 6 — Internal Clinical Notes (CONFIDENTIAL)
    # ─────────────────────────────────────────────────────────

    def render_internal_notes_section
      cmds   = []
      y      = @y
      height = 0

      cmds << section_header("6. CONFIDENTIAL INTERNAL CLINICAL NOTES (DIRECTOR ONLY - FR-135)", y)
      y -= 16; height += 16

      notes_data   = @data[:internal_notes] || {}
      notes        = notes_data[:notes]
      notes_count  = notes_data[:count] || 0
      access       = notes_data[:access_granted]

      # Confidentiality banner
      cmds << "0.85 0.10 0.10 rg"
      cmds << "BT /F2 8 Tf 1 1 1 rg #{LEFT_MARGIN} #{y - 14} Td (STRICTLY CONFIDENTIAL: Internal notes must not be disclosed to parents, teachers, or unauthorized staff.) Tj ET"
      y -= 20; height += 20

      if !access || notes.nil?
        cmds << "0.98 0.98 0.98 rg #{LEFT_MARGIN} #{y - 24} #{RIGHT_MARGIN - LEFT_MARGIN} 26 re f"
        cmds << "0.85 0.85 0.85 RG 0.5 w #{LEFT_MARGIN} #{y - 24} #{RIGHT_MARGIN - LEFT_MARGIN} 26 re S"
        cmds << "BT /F1 8.5 Tf 0.4 0.4 0.4 rg #{LEFT_MARGIN + 10} #{y - 16} Td (#{notes_count} internal notes recorded. Access restricted to Director level and above.) Tj ET"
        height += 30
        return [ cmds.join("\n"), height ]
      end

      if notes.empty?
        cmds << "BT /F1 9 Tf 0.4 0.4 0.4 rg #{LEFT_MARGIN + 6} #{y - 12} Td (No internal notes recorded for this student.) Tj ET"
        height += 18
        return [ cmds.join("\n"), height ]
      end

      cmds << "BT /F1 8 Tf 0.3 0.3 0.3 rg #{LEFT_MARGIN} #{y - 10} Td (#{notes_count} note\\(s\\) on record — most recent first:) Tj ET"
      y -= 14; height += 14

      notes.each_with_index do |note, idx|
        # Page break if needed
        if y - 55 < BOTTOM_MARGIN
          finish_page
          new_page
          y = @y; height = 0
          emit render_page_continuation_header
          y -= 50; height += 50
        end

        note_bg = idx.even? ? "0.98 0.97 1.0 rg" : "0.96 0.95 0.99 rg"
        box_h   = 52
        cmds << "#{note_bg} #{LEFT_MARGIN} #{y - box_h} #{RIGHT_MARGIN - LEFT_MARGIN} #{box_h} re f"
        cmds << "0.70 0.60 0.85 RG 0.6 w #{LEFT_MARGIN} #{y - box_h} #{RIGHT_MARGIN - LEFT_MARGIN} #{box_h} re S"

        recorded   = note[:recorded_at] ? format_date(note[:recorded_at]) : "N/A"
        author     = truncate(note[:author_name] || "Unknown", 30)
        role       = truncate(note[:author_role] || "Staff", 20)
        content    = truncate(note[:content] || "", 120)
        # Wrap long content into two lines
        line1 = content[0..85]  || ""
        line2 = content[86..] || ""

        cmds << "BT /F2 8.5 Tf 0.25 0.05 0.45 rg #{LEFT_MARGIN + 8} #{y - 14} Td (#{escape(author)} \\(#{escape(role)}\\)) Tj ET"
        cmds << "BT /F1 8 Tf 0.45 0.45 0.45 rg #{RIGHT_MARGIN - 100} #{y - 14} Td (#{escape(recorded)}) Tj ET"
        cmds << "BT /F1 8.5 Tf 0.1 0.1 0.1 rg #{LEFT_MARGIN + 8} #{y - 28} Td (#{escape(line1)}) Tj ET"
        cmds << "BT /F1 8.5 Tf 0.1 0.1 0.1 rg #{LEFT_MARGIN + 8} #{y - 40} Td (#{escape(line2)}) Tj ET" unless line2.empty?

        y -= box_h + 4; height += box_h + 4
      end

      height += 6
      [ cmds.join("\n"), height ]
    end

    # ─────────────────────────────────────────────────────────
    # Section 7 — Signatures & sign-off
    # ─────────────────────────────────────────────────────────

    def render_signatures_section
      cmds = []
      y    = @y

      cmds << section_header("7. CLINICAL REVIEW & GOVERNANCE SIGN-OFF", y)
      y -= 20

      box_w = 240
      cmds << "0.8 0.8 0.8 RG 0.5 w"
      cmds << "#{LEFT_MARGIN} #{y - 45} #{box_w} 50 re S"
      cmds << "#{LEFT_MARGIN + 280} #{y - 45} #{box_w} 50 re S"

      cmds << "BT /F2 8.5 Tf 0.2 0.2 0.2 rg"
      cmds << "#{LEFT_MARGIN + 8} #{y - 14} Td (PRIMARY THERAPIST / COORDINATOR) Tj"
      cmds << "#{LEFT_MARGIN + 8} #{y - 40} Td (Signature / Date: _____________________) Tj"
      cmds << "#{LEFT_MARGIN + 288} #{y - 14} Td (PROGRAM DIRECTOR / CLINICAL DIRECTOR) Tj"
      cmds << "#{LEFT_MARGIN + 288} #{y - 40} Td (Signature / Date: _____________________) Tj"
      cmds << "ET"

      y -= 65
      cmds << "BT /F1 7 Tf 0.45 0.45 0.45 rg #{LEFT_MARGIN} #{y} Td (This document is generated by Melue Foundation Therapy Management System. Strictly confidential — authorized personnel only.) Tj ET"

      [ cmds.join("\n"), 80 ]
    end

    # ─────────────────────────────────────────────────────────
    # Data extraction helpers
    # ─────────────────────────────────────────────────────────

    def extract_student_info
      student = @data[:student] || {}
      guardian = student[:guardian] || {}
      {
        name:            student[:full_name] || student[:name] || "Student",
        dob:             student[:date_of_birth] || "N/A",
        age:             student[:age],
        diagnosis:       student[:diagnosis]    || "Autism Spectrum Disorder",
        program_type:    student[:program_type] || "Regular",
        therapy_group:   student[:therapy_group] || "Basic Therapy",
        status:          student[:status]       || "Active Therapy",
        guardian:        guardian[:name]        || "N/A",
        enrollment_date: student[:enrollment_date]&.to_s || "N/A"
      }
    end

    def extract_goals
      raw = @data[:current_goals] || []
      raw.map do |g|
        latest_check = g[:latest_mastery_check]
        {
          name:           g[:goal_name] || g[:name] || "Goal",
          domain:         g[:domain_name] || "General",
          station:        g.dig(:station, :name) || "N/A",
          progress:       g[:progress_percent] || 0,
          status:         g[:status] || "active",
          mastery_status: latest_check ? latest_check[:status] : nil
        }
      end
    end

    # ─────────────────────────────────────────────────────────
    # Rendering primitives
    # ─────────────────────────────────────────────────────────

    def section_header(title, y)
      "BT /F2 10.5 Tf 0.15 0.25 0.55 rg #{LEFT_MARGIN} #{y} Td (#{escape(title)}) Tj ET"
    end

    def field_row(y, label1, val1, label2, val2)
      cmds = []
      cmds << "BT /F2 8.5 Tf 0 0 0 rg #{LEFT_MARGIN + 10} #{y} Td (#{escape(label1)}) Tj /F1 8.5 Tf 120 0 Td (#{escape(val1.to_s)}) Tj ET"
      cmds << "BT /F2 8.5 Tf 0 0 0 rg #{LEFT_MARGIN + 280} #{y} Td (#{escape(label2)}) Tj /F1 8.5 Tf 100 0 Td (#{escape(val2.to_s)}) Tj ET"
      cmds.join("\n")
    end

    def truncate(str, max_len)
      str = str.to_s
      str.length > max_len ? "#{str[0...max_len - 3]}..." : str
    end

    def escape(str)
      str.to_s.gsub("\\", "\\\\\\\\").gsub("(", "\\(").gsub(")", "\\)")
    end

    def format_date(val)
      return val.to_s unless val.respond_to?(:strftime)

      val.strftime("%b %d, %Y")
    rescue
      val.to_s[0..9]
    end

    # ─────────────────────────────────────────────────────────
    # PDF assembler — builds valid %PDF-1.4 with xref table
    # ─────────────────────────────────────────────────────────

    def assemble_pdf_document(pages_commands)
      objects = []

      # Object 1: Catalog
      objects << "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj"

      # Plan object IDs
      page_obj_ids    = []
      content_obj_ids = []
      pages_commands.each_with_index do |_, idx|
        page_id    = 3 + (idx * 2)
        content_id = page_id + 1
        page_obj_ids    << page_id
        content_obj_ids << content_id
      end
      font_base_id    = 3 + (pages_commands.size * 2)
      helvetica_id    = font_base_id
      helvetica_bold  = font_base_id + 1

      kids = page_obj_ids.map { |id| "#{id} 0 R" }.join(" ")
      objects << "2 0 obj\n<< /Type /Pages /Kids [#{kids}] /Count #{pages_commands.size} >>\nendobj"

      pages_commands.each_with_index do |cmd_stream, idx|
        page_id    = page_obj_ids[idx]
        content_id = content_obj_ids[idx]
        stream_bytes = cmd_stream.bytesize

        objects << "#{page_id} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] /Contents #{content_id} 0 R /Resources << /Font << /F1 #{helvetica_id} 0 R /F2 #{helvetica_bold} 0 R >> >> >>\nendobj"
        objects << "#{content_id} 0 obj\n<< /Length #{stream_bytes} >>\nstream\n#{cmd_stream}\nendstream\nendobj"
      end

      objects << "#{helvetica_id} 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj"
      objects << "#{helvetica_bold} 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj"

      # Build raw PDF bytes with xref table
      pdf = +"%PDF-1.4\n%\xE2\xE3\xCF\xD3\n"
      xref_offsets = [0]

      objects.each do |obj|
        xref_offsets << pdf.bytesize
        pdf << obj << "\n"
      end

      xref_start = pdf.bytesize
      pdf << "xref\n0 #{objects.size + 1}\n"
      pdf << "0000000000 65535 f \n"
      xref_offsets[1..].each { |off| pdf << sprintf("%010d 00000 n \n", off) }
      pdf << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref_start}\n%%EOF\n"
      pdf
    end
  end
end
