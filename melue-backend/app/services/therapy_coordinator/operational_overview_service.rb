# frozen_string_literal: true

module TherapyCoordinator
  class OperationalOverviewService < ApplicationService
    attr_reader :params, :current_user

    def initialize(params = {}, current_user = nil)
      @params = params
      @current_user = current_user
    end

    def call
      target_date = parse_date(params[:date]) || Date.current
      eval_time = parse_time(params[:current_time]) || Time.current

      blocks = SessionBlockDefinition.active.ordered.to_a
      teachers = StaffMember.where(role: [ "teacher", "therapy_coordinator" ]).order(:full_name)

      # 1. Block definitions with current/upcoming flags
      current_block = find_current_block(blocks, eval_time)
      upcoming_block = find_upcoming_block(blocks, eval_time)

      serialized_blocks = blocks.map do |block|
        {
          id: block.id,
          name: block.name,
          round: block.round,
          start_time: block.start_time,
          end_time: block.end_time,
          is_current: current_block&.id == block.id,
          is_upcoming: upcoming_block&.id == block.id
        }
      end

      # 2. Fetch assignments for the date
      assignments = TeacherStudentAssignment
        .scheduled
        .includes(:student, :therapy_station, :therapy_room)
        .where(scheduled_date: target_date, teacher_id: teachers.map(&:id))

      assignments_by_teacher_and_block = assignments.group_by { |a| [ a.teacher_id, a.session_block_definition_id ] }
      assignments_by_teacher = assignments.group_by(&:teacher_id)

      # 3. Fetch unavailabilities for the date
      unavailabilities = StaffAvailability
        .where(staff_member_id: teachers.map(&:id), unavailable_date: target_date)
        .includes(:session_block_definition)

      unavailabilities_by_teacher = unavailabilities.group_by(&:staff_member_id)

      # 4. Capacity config
      max_capacity = SessionScheduleConfig.instance.staff_to_student_capacity

      # 5. Teacher summaries
      teacher_cards = teachers.map do |teacher|
        teacher_unavails = unavailabilities_by_teacher[teacher.id] || []
        full_day_unavail = teacher_unavails.find(&:full_day?)
        is_fully_unavailable = full_day_unavail.present?

        teacher_assignments_today = assignments_by_teacher[teacher.id] || []
        total_assignments_today = teacher_assignments_today.size

        # Daily blocks breakdown
        block_schedules = blocks.map do |block|
          block_unavail = teacher_unavails.find { |u| u.session_block_definition_id == block.id }
          is_block_unavail = is_fully_unavailable || block_unavail.present?
          block_reason = block_unavail&.reason || full_day_unavail&.reason

          block_assignments = assignments_by_teacher_and_block[[ teacher.id, block.id ]] || []

          {
            block_id: block.id,
            block_name: block.name,
            round: block.round,
            start_time: block.start_time,
            end_time: block.end_time,
            is_unavailable: is_block_unavail,
            unavailability_reason: block_reason,
            students_count: block_assignments.size,
            assignments: block_assignments.map do |a|
              {
                id: a.id,
                student_id: a.student_id,
                student_name: a.student&.full_name,
                therapy_group: a.student&.therapy_group,
                program_type: a.student&.program_type,
                station_id: a.therapy_station_id,
                station_name: a.therapy_station&.name,
                room_id: a.therapy_room_id,
                room_name: a.therapy_room&.name,
                status: a.status
              }
            end
          }
        end

        available_capacity = is_fully_unavailable ? 0 : [ max_capacity - total_assignments_today, 0 ].max

        {
          teacher_id: teacher.id,
          teacher_name: teacher.full_name,
          teacher_role: teacher.role,
          staff_number: teacher.staff_number,
          is_available: !is_fully_unavailable,
          unavailabilities: teacher_unavails.map do |u|
            {
              id: u.id,
              date: u.unavailable_date,
              full_day: u.full_day?,
              session_block_definition_id: u.session_block_definition_id,
              session_block_name: u.session_block_definition&.name,
              reason: u.reason
            }
          end,
          capacity: {
            current: total_assignments_today,
            max: max_capacity,
            available: available_capacity,
            percentage: total_assignments_today.positive? ? (total_assignments_today.to_f / max_capacity * 100).round : 0
          },
          blocks: block_schedules
        }
      end

      # 6. Unassigned student warnings (FR-125)
      alert_service = UnassignedStudentsAlertService.new({ date: target_date, current_time: eval_time }, current_user)
      alert_result = alert_service.call
      alerts_data = alert_result.success? ? alert_result.data : { alerts: [], total_unassigned_count: 0 }

      # 7. Summary counters
      total_teachers_count = teachers.size
      unavailable_teachers_count = teacher_cards.count { |t| !t[:is_available] }
      available_teachers_count = total_teachers_count - unavailable_teachers_count

      success({
        date: target_date,
        summary: {
          total_teachers: total_teachers_count,
          available_teachers: available_teachers_count,
          unavailable_teachers: unavailable_teachers_count,
          total_assignments: assignments.size,
          unassigned_students_count: alerts_data[:total_unassigned_count] || 0
        },
        blocks: serialized_blocks,
        teachers: teacher_cards,
        unassigned_alerts: alerts_data[:alerts] || []
      })
    end

    private

    def parse_date(raw)
      return nil if raw.blank?

      raw.is_a?(Date) ? raw : Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def parse_time(raw)
      return nil if raw.blank?

      raw.is_a?(Time) ? raw : Time.zone.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def find_current_block(blocks, eval_time)
      blocks.find do |block|
        start_t = eval_time.change(hour: block.start_time.hour, min: block.start_time.min, sec: block.start_time.sec)
        end_t = eval_time.change(hour: block.end_time.hour, min: block.end_time.min, sec: block.end_time.sec)
        eval_time >= start_t && eval_time <= end_t
      end
    end

    def find_upcoming_block(blocks, eval_time)
      upcoming = blocks.find do |block|
        start_t = eval_time.change(hour: block.start_time.hour, min: block.start_time.min, sec: block.start_time.sec)
        eval_time < start_t
      end

      if upcoming.nil? && blocks.any?
        first_start = eval_time.change(hour: blocks.first.start_time.hour, min: blocks.first.start_time.min, sec: blocks.first.start_time.sec)
        upcoming = blocks.first if eval_time < first_start
      end

      upcoming
    end
  end
end
