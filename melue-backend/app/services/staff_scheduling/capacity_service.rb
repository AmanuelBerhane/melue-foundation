# app/services/staff_scheduling/capacity_service.rb
module StaffScheduling
  class CapacityService < ApplicationService
    def self.for_teacher_on_date(teacher_id, date, block_id = nil)
      assignments = TeacherStudentAssignment
        .scheduled
        .where(teacher_id: teacher_id)
        .where(scheduled_date: date)

      assignments = assignments.where(session_block_definition_id: block_id) if block_id

      capacity_config = SessionScheduleConfig.instance
      max_capacity = capacity_config.staff_to_student_capacity

      teacher = StaffMember.find_by(id: teacher_id)
      is_unavailable = teacher&.unavailable_for_date?(date, block_id) || false
      unavailability = teacher&.staff_availabilities&.active_on(date, block_id)&.first

      {
        current: assignments.count,
        max: max_capacity,
        available: is_unavailable ? 0 : [ max_capacity - assignments.count, 0 ].max,
        is_unavailable: is_unavailable,
        unavailability_reason: unavailability&.reason,
        assignments: assignments
      }
    end

    def self.check_assignment_valid?(teacher_id, student_id, date, block_id, ignore_id: nil)
      teacher = StaffMember.find_by(id: teacher_id)
      if teacher&.unavailable_for_date?(date, block_id)
        return { valid: false, reason: "Teacher is unavailable for this date/block" }
      end

      capacity_config = SessionScheduleConfig.instance
      max_students = capacity_config.staff_to_student_capacity

      # Check teacher capacity
      teacher_assignments = TeacherStudentAssignment
        .scheduled
        .where(teacher_id: teacher_id)
        .where(scheduled_date: date)
        .where(session_block_definition_id: block_id)
      teacher_assignments = teacher_assignments.where.not(id: ignore_id) if ignore_id

      if teacher_assignments.count >= max_students
        return { valid: false, reason: "Teacher capacity exceeded" }
      end

      # Check student double-booking
      student_assignments = TeacherStudentAssignment
        .scheduled
        .where(student_id: student_id)
        .where(scheduled_date: date)
        .where(session_block_definition_id: block_id)
      student_assignments = student_assignments.where.not(id: ignore_id) if ignore_id

      if student_assignments.exists?
        return { valid: false, reason: "Student already assigned to this block" }
      end

      { valid: true }
    end
  end
end
