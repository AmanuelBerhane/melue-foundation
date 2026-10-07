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
    staff_members = StaffMember.includes(user: :roles).all.map do |sm|
      role_name = sm.user&.roles&.first&.name&.humanize || "Staff"
      {
        id: sm.id.to_s,
        name: sm.full_name,
        role: (sm.role.presence || "teacher").to_s.downcase,
        roleName: role_name,
        assignedStudents: []
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
end
