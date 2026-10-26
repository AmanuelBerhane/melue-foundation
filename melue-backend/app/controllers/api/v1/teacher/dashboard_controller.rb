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
    unless staff
      return render json: {
        periodLabel: "6-Week Baseline Assessment",
        stats: { total: 0, completed: 0, inProgress: 0, notStarted: 0 },
        students: []
      }
    end

    # Strictly filter students explicitly assigned to the authenticated teacher with status "in_assessment"
    scoped_students = Student.joins(:teacher_student_assignments)
                             .where(teacher_student_assignments: { teacher_id: staff.id, discarded_at: nil })
                             .where(status: "in_assessment")
                             .distinct
                             .order(:first_name, :last_name)

    cycles = AssessmentCycle.kept
                            .where(student_id: scoped_students.map(&:id))
                            .includes(:skills_assessment, :behavior_assessment, :preference_assessment)
                            .index_by(&:student_id)

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

      overall_score = ((skills_prog + behavior_prog + pref_prog + sensory_prog) / 4.0).round

      {
        id: s.id.to_s,
        fullName: full_name,
        name: full_name,
        initial: full_name[0] || "S",
        age: s.age || 6,
        program: s.program_type.to_s.humanize,
        therapist: staff.full_name,
        status: s.status,
        score: overall_score,
        ablls: { status: skills_status, progress: skills_prog },
        behavior: { status: behavior_status, progress: behavior_prog },
        preference: { status: pref_status, progress: pref_prog },
        sensory: { status: sensory_status, progress: sensory_prog },
        assessment_cycle_id: cycle&.id
      }
    end

    total = students_data.size
    completed_count = students_data.count do |c|
      c[:ablls][:status] == "Completed" &&
      c[:behavior][:status] == "Completed" &&
      c[:preference][:status] == "Completed" &&
      c[:sensory][:status] == "Completed"
    end
    in_progress_count = students_data.count do |c|
      [c[:ablls][:status], c[:behavior][:status], c[:preference][:status], c[:sensory][:status]].any? { |st| st == "In Progress" || st == "Completed" } &&
      ![c[:ablls][:status], c[:behavior][:status], c[:preference][:status], c[:sensory][:status]].all? { |st| st == "Completed" }
    end
    not_started_count = total - completed_count - in_progress_count

    render json: {
      periodLabel: "6-Week Baseline Assessment",
      stats: {
        total: total,
        completed: completed_count,
        inProgress: in_progress_count,
        notStarted: not_started_count
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
      return render json: { error: "Not authorized for this student" }, status: :forbidden unless assigned
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
