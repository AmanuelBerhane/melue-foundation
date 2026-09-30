# frozen_string_literal: true

module TherapyCoordinator
  class UnassignedStudentsAlertService < ApplicationService
    attr_reader :params, :current_user

    def initialize(params = {}, current_user = nil)
      @params = params
      @current_user = current_user
    end

    def call
      target_date = parse_date(params[:date]) || Date.current
      eval_time = parse_time(params[:current_time]) || Time.current

      active_blocks = SessionBlockDefinition.active.ordered.to_a
      return success(empty_response(target_date)) if active_blocks.empty?

      current_block = find_current_block(active_blocks, eval_time)
      upcoming_block = find_upcoming_block(active_blocks, eval_time)

      # Determine which blocks to check for unassigned alerts
      blocks_to_check = determine_blocks_to_check(active_blocks, current_block, upcoming_block)

      active_students = fetch_active_students
      alerts = []

      blocks_to_check.each do |block|
        is_curr = (current_block&.id == block.id)

        assigned_student_ids = TeacherStudentAssignment
          .scheduled
          .where(scheduled_date: target_date, session_block_definition_id: block.id)
          .pluck(:student_id)

        unassigned_students = active_students.reject { |s| assigned_student_ids.include?(s.id) }

        unassigned_students.each do |student|
          alerts << {
            student_id: student.id,
            student_name: student.full_name,
            therapy_group: student.therapy_group,
            program_type: student.program_type,
            session_block_definition_id: block.id,
            session_block_name: block.name,
            session_block_round: block.round,
            start_time: block.start_time,
            end_time: block.end_time,
            is_current_block: is_curr,
            severity: is_curr ? "high" : "warning",
            message: "#{student.full_name} is not assigned to a teacher for #{is_curr ? 'current' : 'upcoming'} block #{block.name}"
          }
        end
      end

      success({
        target_date: target_date,
        current_block: serialize_block(current_block),
        upcoming_block: serialize_block(upcoming_block),
        total_unassigned_count: alerts.size,
        alerts: alerts
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
      # First block starting after current time
      upcoming = blocks.find do |block|
        start_t = eval_time.change(hour: block.start_time.hour, min: block.start_time.min, sec: block.start_time.sec)
        eval_time < start_t
      end

      # If time is before all blocks, first block is upcoming
      if upcoming.nil? && blocks.any?
        first_start = eval_time.change(hour: blocks.first.start_time.hour, min: blocks.first.start_time.min, sec: blocks.first.start_time.sec)
        upcoming = blocks.first if eval_time < first_start
      end

      upcoming
    end

    def determine_blocks_to_check(blocks, current_block, upcoming_block)
      if params[:session_block_definition_id].present?
        target = blocks.find { |b| b.id.to_s == params[:session_block_definition_id].to_s }
        return [ target ].compact
      end

      [ current_block, upcoming_block ].compact.uniq
    end

    def fetch_active_students
      Student.where(status: %w[active active_therapy])
             .where.not(status: %w[discharged withdrawn archived])
             .order(:first_name, :last_name)
    end

    def serialize_block(block)
      return nil unless block

      {
        id: block.id,
        name: block.name,
        round: block.round,
        start_time: block.start_time,
        end_time: block.end_time
      }
    end

    def empty_response(target_date)
      {
        target_date: target_date,
        current_block: nil,
        upcoming_block: nil,
        total_unassigned_count: 0,
        alerts: []
      }
    end
  end
end
