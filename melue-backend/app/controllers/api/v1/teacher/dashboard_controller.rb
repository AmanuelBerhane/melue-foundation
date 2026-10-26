# frozen_string_literal: true

class Api::V1::Teacher::DashboardController < Api::V1::BaseController
  before_action :authenticate_user!

  def show
    staff = current_user&.staff_member

    # Filter assigned students for this specific teacher
    assigned_students = staff ? Student.joins(:teacher_student_assignments)
                                       .where(teacher_student_assignments: { teacher_id: staff.id, discarded_at: nil })
                                       .distinct : []

    students = assigned_students.map do |s|
      full_name = "#{s.first_name} #{s.last_name}".strip
      {
        id: s.id.to_s,
        name: full_name,
        initial: full_name[0] || "S"
      }
    end

    schedule_students = students.first(2)

    # Today's active assignment/session for this teacher
    today_tsa = staff ? staff.teacher_student_assignments.scheduled.for_today.first : nil
    station = today_tsa&.therapy_station || (schedule_students.any? ? TherapyStation.first : nil)
    room = today_tsa&.therapy_room || (schedule_students.any? ? TherapyRoom.first : nil)
    block = today_tsa&.session_block_definition || (schedule_students.any? ? SessionBlockDefinition.first : nil)

    today_schedule = if schedule_students.any?
      {
        stationName: station&.name || "Station 1",
        roomName: room&.name || "Room 1A",
        sessionBlock: block&.name || "Morning Session",
        startTime: block&.start_time ? block.start_time.strftime("%I:%M %p") : "08:00 AM",
        endTime: block&.end_time ? block.end_time.strftime("%I:%M %p") : "09:30 AM",
        startsIn: "Scheduled",
        students: schedule_students
      }
    else
      nil
    end

    # Filter only students assigned to this teacher with "in_assessment" status
    assessment_students = staff ? Student.joins(:teacher_student_assignments)
                                         .where(teacher_student_assignments: { teacher_id: staff.id, discarded_at: nil })
                                         .where(status: "in_assessment")
                                         .distinct : []

    if staff && assessment_students.empty?
      assessment_students = Student.kept.where(status: "in_assessment").distinct.order(:first_name, :last_name).first(2)
    end

    cycles = AssessmentCycle.kept.where(student_id: assessment_students.map(&:id)).includes(:skills_assessment).index_by(&:student_id)

    assessment_tasks = assessment_students.map do |s|
      cycle = cycles[s.id]
      skills = cycle&.skills_assessment
      full_name = "#{s.first_name} #{s.last_name}".strip
      status = skills&.submitted? ? "Completed" : (skills&.in_progress? ? "In Progress" : "Not Started")
      progress = skills&.progress_percent || (status == "Completed" ? 100 : 0)

      {
        id: "assess-#{s.id}",
        studentId: s.id.to_s,
        studentName: full_name,
        studentInitial: full_name[0] || "S",
        assessmentName: "ABLLS Assessment",
        status: status,
        progress: progress
      }
    end

    notifications = Notification.for_recipient(current_user.id).limit(5).map do |n|
      title = begin
        n.payload["title"] || n.type.humanize
      rescue StandardError
        n.type.humanize
      end
      {
        id: n.id.to_s,
        type: "alert",
        title: title,
        source: "System",
        timeAgo: "Just now",
        unread: !n.read?
      }
    end

    render json: {
      todaySchedule: today_schedule,
      assessmentTasks: assessment_tasks,
      pendingMasteryChecks: [],
      notifications: notifications
    }
  end

  def assessments
    staff = current_user&.staff_member
    clinician_data = {
      id: staff&.id&.to_s,
      name: staff&.full_name || current_user&.email || "Assigned Clinician",
      email: current_user&.email
    }

    unless staff
      return render json: {
        clinician: clinician_data,
        periodLabel: "6-Week Baseline Assessment",
        stats: {
          totalStudents: 0,
          totalRequiredModules: 0,
          completedModules: 0,
          inProgressModules: 0,
          pendingModules: 0,
          total: 0,
          completed: 0,
          inProgress: 0,
          notStarted: 0
        },
        students: []
      }
    end

    # Filter students explicitly assigned to the authenticated teacher with status in_assessment / registered
    assigned_student_ids = TeacherStudentAssignment.kept
                                                   .where(teacher_id: staff.id)
                                                   .pluck(:student_id)

    scoped_students = Student.kept
                             .where(id: assigned_student_ids)
                             .where(status: %w[in_assessment registered enrolled])
                             .distinct
                             .order(:first_name, :last_name)

    # Resilient fallback: If no explicit assessment assignment for this teacher yet,
    # load active cohort students in assessment so any teacher can view & score assessments
    if scoped_students.empty?
      scoped_students = Student.kept
                               .where(status: "in_assessment")
                               .distinct
                               .order(:first_name, :last_name)
    end

    cycles = AssessmentCycle.kept
                            .where(student_id: scoped_students.map(&:id))
                            .includes(:skills_assessment, :behavior_assessment, :preference_assessment)
                            .index_by(&:student_id)

    # Ensure every assessment student has an active cycle so teachers can immediately record data
    scoped_students.each do |s|
      cycles[s.id] ||= AssessmentCycle.kept.find_or_create_by!(student: s, status: "in_progress") do |c|
        c.started_on = Date.current
      end
    end

    total_completed_submodules = 0
    total_in_progress_submodules = 0
    total_pending_submodules = 0

    students_data = scoped_students.map do |s|
      full_name = "#{s.first_name} #{s.last_name}".strip
      cycle = cycles[s.id]
      skills = cycle&.skills_assessment
      behavior = cycle&.behavior_assessment
      pref = cycle&.preference_assessment
      sensory = SensoryAssessment.where(student_id: s.id).order(created_at: :desc).first rescue nil

      skills_status = skills&.submitted? ? "Completed" : (skills&.in_progress? ? "In Progress" : "Not Started")
      behavior_status = (behavior&.status == "completed" || behavior&.status == "submitted") ? "Completed" : (behavior&.status == "in_progress" ? "In Progress" : "Not Started")
      pref_status = (pref&.status == "submitted" || pref&.status == "completed") ? "Completed" : "Not Started"
      sensory_status = (sensory&.status == "completed" || sensory&.status == "submitted") ? "Completed" : "Not Started"

      skills_prog = skills&.progress_percent || (skills_status == "Completed" ? 100 : 0)
      behavior_prog = behavior_status == "Completed" ? 100 : (behavior_status == "In Progress" ? 50 : 0)
      pref_prog = pref_status == "Completed" ? 100 : 0
      sensory_prog = sensory_status == "Completed" ? 100 : 0

      module_statuses = [skills_status, behavior_status, pref_status, sensory_status]
      completed_count = module_statuses.count("Completed")
      in_prog_count = module_statuses.count("In Progress")
      not_start_count = module_statuses.count("Not Started")

      total_completed_submodules += completed_count
      total_in_progress_submodules += in_prog_count
      total_pending_submodules += not_start_count

      # Calculate activity timestamps
      activity_timestamps = [
        skills&.updated_at,
        behavior&.updated_at,
        pref&.updated_at,
        sensory&.updated_at,
        cycle&.updated_at,
        s.updated_at
      ].compact

      latest_activity = activity_timestamps.max
      days_since = latest_activity ? ((Time.current - latest_activity) / 1.day).to_i : 0

      # NFR-022: Check if any in-progress draft untouched for > 7 days
      in_progress_modules = [skills, behavior, pref, sensory].compact.select do |m|
        (m.respond_to?(:in_progress?) ? m.in_progress? : m.status == "in_progress") || (m.respond_to?(:draft?) && m.draft?)
      end

      stale_draft = in_progress_modules.find { |m| m.updated_at.present? && m.updated_at < 7.days.ago }
      has_stale_draft = stale_draft.present?
      stale_days = stale_draft ? ((Time.current - stale_draft.updated_at) / 1.day).to_i : (days_since > 7 ? days_since : 0)

      # Color-coded status dot: Green = Active/On Track, Amber = Delayed Drafts (> 7 days), Gray = Not Started
      status_dot = if completed_count == 4
        "green"
      elsif has_stale_draft || (in_prog_count > 0 && days_since > 7)
        "amber"
      elsif completed_count == 0 && in_prog_count == 0
        "gray"
      else
        "green"
      end

      time_ago_str = if latest_activity.blank?
        "Not started"
      elsif days_since == 0
        "Today"
      elsif days_since == 1
        "Yesterday"
      else
        "#{days_since} days ago"
      end

      overall_score = ((skills_prog + behavior_prog + pref_prog + sensory_prog) / 4.0).round

      {
        id: s.id.to_s,
        fullName: full_name,
        name: full_name,
        initial: (full_name[0] || "S").upcase,
        age: s.age || 6,
        program: s.program_type.to_s.humanize.presence || "Regular Program",
        program_type: s.program_type.presence || "Regular Program",
        therapist: staff.full_name,
        status: s.status,
        score: overall_score,
        completed_modules: completed_count,
        last_assessment_activity_at: latest_activity&.iso8601,
        last_activity_display: time_ago_str,
        days_since_last_activity: days_since,
        has_stale_draft: has_stale_draft,
        stale_days: stale_days,
        status_dot: status_dot,
        modules: {
          skills: {
            status: skills_status,
            progress_percentage: skills_prog,
            label: "Skills (ABLLS-R)",
            subtitle: "Basic Language & Learning Skills"
          },
          behavior: {
            status: behavior_status,
            progress_percentage: behavior_prog,
            label: "Behavior (MASS / FAST / ABC)",
            subtitle: "Functional Behavior Tracking"
          },
          preference: {
            status: pref_status,
            progress_percentage: pref_prog,
            label: "Preference",
            subtitle: "Reinforcer Hierarchy Assessment"
          },
          sensory: {
            status: sensory_status,
            progress_percentage: sensory_prog,
            label: "Sensory Time Engagement",
            subtitle: "Sensory Modulation & Regulation"
          }
        },
        ablls: { status: skills_status, progress: skills_prog },
        behavior: { status: behavior_status, progress: behavior_prog },
        preference: { status: pref_status, progress: pref_prog },
        sensory: { status: sensory_status, progress: sensory_prog },
        assessment_cycle_id: cycle&.id
      }
    end

    total_students = students_data.size
    completed_students_count = students_data.count { |c| c[:completed_modules] == 4 }
    in_progress_students_count = students_data.count { |c| c[:completed_modules] < 4 && c[:score] > 0 }
    not_started_students_count = total_students - completed_students_count - in_progress_students_count

    render json: {
      clinician: clinician_data,
      periodLabel: "6-Week Baseline Assessment",
      stats: {
        totalStudents: total_students,
        totalRequiredModules: total_students * 4,
        completedModules: total_completed_submodules,
        inProgressModules: total_in_progress_submodules,
        pendingModules: total_pending_submodules,
        total: total_students,
        completed: completed_students_count,
        inProgress: in_progress_students_count,
        notStarted: not_started_students_count
      },
      students: students_data
    }
  end

  def submit_assessments
    staff = current_user&.staff_member
    student = Student.find_by(id: params[:student_id])

    return render json: { error: "Student not found" }, status: :not_found unless student

    if staff
      assigned = TeacherStudentAssignment.kept.where(teacher_id: staff.id, student_id: student.id).exists?
      is_in_assessment = student.status == "in_assessment"
      return render json: { error: "Not authorized for this student" }, status: :forbidden unless (assigned || is_in_assessment)
    end

    cycle = AssessmentCycle.kept.find_or_create_by!(student: student, status: "in_progress") do |c|
      c.started_on = Date.current
    end

    # Transition student status: "in_assessment" -> "assessment_complete" (routes to Program Director review SCR-PD-002)
    student.update!(status: "assessment_complete")
    cycle.update!(status: "complete", completed_on: Date.current)

    render json: {
      success: true,
      student_id: student.id.to_s,
      status: student.status,
      display_status: "Assessment Complete / Pending Review"
    }
  end
end
