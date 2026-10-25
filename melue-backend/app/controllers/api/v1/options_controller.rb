# frozen_string_literal: true

class Api::V1::OptionsController < Api::V1::BaseController
  before_action :authenticate_user!

  # GET /api/v1/options/students
  def students
    students = Student.all.map do |s|
      age = s.date_of_birth ? (Date.current.year - s.date_of_birth.year) : 6
      {
        id: s.id.to_s,
        studentId: s.student_id,
        student_id: s.student_id,
        name: "#{s.first_name} #{s.last_name}".strip,
        age: age,
        phase: s.respond_to?(:phase) ? s.phase : "active",
        status: s.status.to_s.humanize,
        program: s.program_type.to_s.humanize
      }
    end

    render json: students
  end

  # GET /api/v1/options/staff
  def staff
    assignments_by_teacher = TeacherStudentAssignment
      .where(status: %w[scheduled completed])
      .pluck(:teacher_id, :student_id)
      .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(teacher_id, student_id), h|
        h[teacher_id] << student_id.to_s unless h[teacher_id].include?(student_id.to_s)
      end

    if assignments_by_teacher.empty?
      assignments_by_teacher = TeacherStudentAssignment
        .pluck(:teacher_id, :student_id)
        .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(teacher_id, student_id), h|
          h[teacher_id] << student_id.to_s unless h[teacher_id].include?(student_id.to_s)
        end
    end

    staff_members = StaffMember.includes(user: :roles).all.map do |sm|
      role_name = sm.user&.roles&.first&.name&.humanize || "Staff"
      assigned_ids = assignments_by_teacher[sm.id] || []
      {
        id: sm.id.to_s,
        name: sm.full_name,
        role: (sm.role.presence || "teacher").to_s.downcase,
        roleName: role_name,
        assignedStudents: assigned_ids,
        assignedStudentCount: assigned_ids.length,
        assigned_students_count: assigned_ids.length
      }
    end

    render json: staff_members
  end

  # GET /api/v1/options/rooms
  def rooms
    rooms = TherapyRoom.all.map do |r|
      { id: r.id.to_s, name: r.name }
    end

    if rooms.empty?
      rooms = [
        { id: "room-1", name: "Sunrise Room" },
        { id: "room-2", name: "Horizon Room" },
        { id: "room-3", name: "Sensory Room" }
      ]
    end

    render json: rooms
  end

  # GET /api/v1/options/programs
  def programs
    programs = [ "Regular Morning", "Regular Afternoon", "Pulled Out" ]
    render json: programs
  end

  # GET /api/v1/options/therapy_groups
  def therapy_groups
    groups = [ "Basic", "Functional Living" ]
    render json: groups
  end

  # GET /api/v1/options/statuses
  def statuses
    statuses = [ "Active", "Inactive", "Draft", "Archived" ]
    if defined?(Student)
      db_statuses = Student.distinct.pluck(:status).compact.map do |s|
        case s.to_s.downcase
        when "active", "active_therapy", "registered", "ready_for_iup", "in_assessment", "assessment_complete"
          "Active"
        when "draft", "pending_review"
          "Draft"
        when "archived", "discharged", "withdrawn"
          "Archived"
        when "inactive"
          "Inactive"
        else
          s.to_s.humanize.titleize
        end
      end
      statuses = (statuses + db_statuses).uniq
    end

    render json: statuses
  end
end
