# frozen_string_literal: true

module TherapyCoordinator
  class MarkTeacherUnavailableService < ApplicationService
    attr_reader :params, :current_user

    def initialize(params = {}, current_user = nil)
      @params = params
      @current_user = current_user
    end

    def call
      teacher = find_teacher
      return failure("Teacher not found") unless teacher

      date = parse_date
      return failure("Invalid unavailable_date format. Expected YYYY-MM-DD") unless date

      block_id = params[:session_block_definition_id]
      if block_id.present?
        block = SessionBlockDefinition.find_by(id: block_id)
        return failure("Session block definition not found") unless block
      end

      availability = StaffAvailability.new(
        staff_member: teacher,
        session_block_definition_id: block_id,
        unavailable_date: date,
        reason: params[:reason]
      )

      if availability.save
        impacted_assignments = find_impacted_assignments(teacher.id, date, block_id)

        success(
          availability: availability,
          impacted_assignments_count: impacted_assignments.count,
          impacted_assignments: impacted_assignments
        )
      else
        failure(availability.errors.full_messages.join(", "))
      end
    end

    private

    def find_teacher
      StaffMember.find_by(id: params[:teacher_id] || params[:staff_member_id])
    end

    def parse_date
      raw_date = params[:unavailable_date] || params[:date]
      return nil if raw_date.blank?

      raw_date.is_a?(Date) ? raw_date : Date.parse(raw_date.to_s)
    rescue ArgumentError
      nil
    end

    def find_impacted_assignments(teacher_id, date, block_id)
      scope = TeacherStudentAssignment
        .scheduled
        .includes(:student, :session_block_definition, :therapy_station, :therapy_room)
        .where(teacher_id: teacher_id, scheduled_date: date)

      scope = scope.where(session_block_definition_id: block_id) if block_id.present?
      scope
    end
  end
end
