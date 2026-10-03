# frozen_string_literal: true

module Director
  # SCR-DIR-002 — assigns one student to a teacher for a session block on a date.
  #
  # Enforces:
  #   FR-118 — the configured staff-to-student capacity per teacher per block
  #   FR-120 — a student cannot be booked to two teachers in the same block
  #   FR-122 — a teacher marked unavailable cannot receive assignments
  #
  # Failures carry an HTTP status hint and a machine-readable `code` so the
  # scheduling screen can show the right message without parsing text.
  class AssignStudentService < ApplicationService
    def initialize(teacher:, student:, block:, date:, station: nil, room: nil)
      @teacher = teacher
      @student = student
      @block = block
      @date = date
      @room = room
      @station = station || room&.therapy_station
    end

    def call
      return reject(:not_found, "Teacher not found", "teacher_not_found") unless @teacher
      return reject(:not_found, "Student not found", "student_not_found") unless @student
      return reject(:not_found, "Session block not found", "block_not_found") unless @block

      resolve_location!
      return reject(:unprocessable_entity, "No therapy station/room is configured", "location_missing") unless @station && @room

      TeacherStudentAssignment.transaction do
        # Serialize concurrent assignments to the same teacher so two requests
        # cannot both pass the capacity check.
        @teacher.lock!

        conflict = double_booking
        return reject_double_booking(conflict) if conflict

        if @teacher.unavailable_for_date?(@date, @block.id)
          return reject(:unprocessable_entity, "#{@teacher.full_name} is unavailable for this block", "teacher_unavailable")
        end

        if capacity_used >= capacity_limit
          return reject(:unprocessable_entity,
                        "#{@teacher.full_name} has reached the capacity limit of #{capacity_limit} students for this block",
                        "capacity_exceeded")
        end

        assignment = build_assignment
        assignment.save!
        success(assignment: assignment, capacity: capacity_indicator)
      end
    rescue ActiveRecord::RecordNotUnique
      reject(:conflict, "#{@student.full_name} is already assigned for this block", "double_booking")
    rescue ActiveRecord::RecordInvalid => e
      reject(:unprocessable_entity, e.record.errors.full_messages.join(", "), "invalid")
    end

    private

    def resolve_location!
      @station ||= TherapyStation.kept.order(:name).first
      @room ||= TherapyRoom.kept.where(therapy_station: @station).order(:name).first if @station
    end

    def block_scope
      TeacherStudentAssignment.kept.scheduled.for_date(@date).for_block(@block.id)
    end

    def double_booking
      block_scope.includes(:teacher).find_by(student_id: @student.id)
    end

    def capacity_used
      block_scope.for_teacher(@teacher.id).count
    end

    def capacity_limit
      @capacity_limit ||= SessionScheduleConfig.instance.staff_to_student_capacity
    end

    def capacity_indicator
      { current: capacity_used, max: capacity_limit }
    end

    # The unique index covers (student, block, date) regardless of status, so
    # a previously cancelled or discarded row is revived instead of duplicated.
    def build_assignment
      assignment = TeacherStudentAssignment.find_or_initialize_by(
        student_id: @student.id,
        session_block_definition_id: @block.id,
        scheduled_date: @date
      )
      assignment.assign_attributes(
        teacher: @teacher,
        therapy_station: @station,
        therapy_room: @room,
        status: "scheduled",
        discarded_at: nil
      )
      assignment
    end

    def reject_double_booking(existing)
      message = if existing.teacher_id == @teacher.id
        "#{@student.full_name} is already assigned to #{@teacher.full_name} for this block"
      else
        "#{@student.full_name} is already assigned to #{existing.teacher.full_name} for this block"
      end

      ServiceResult.new(
        success: false,
        error: message,
        status: :conflict,
        data: { code: "double_booking", conflicting_teacher_id: existing.teacher_id,
                conflicting_teacher_name: existing.teacher.full_name }
      )
    end

    def reject(status, message, code)
      ServiceResult.new(success: false, error: message, status: status, data: { code: code })
    end
  end
end
