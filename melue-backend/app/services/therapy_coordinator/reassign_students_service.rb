# frozen_string_literal: true

module TherapyCoordinator
  class ReassignStudentsService < ApplicationService
    attr_reader :params, :current_user

    def initialize(params = {}, current_user = nil)
      @params = params
      @current_user = current_user
    end

    def call
      assignments_data = normalize_assignments_data
      return failure("No assignments provided for reassignment") if assignments_data.empty?

      reassigned_records = []
      error_message = nil

      ActiveRecord::Base.transaction do
        # Group proposed additions by [target_teacher_id, scheduled_date, block_id] to track capacity additions within the batch
        batch_additions = Hash.new(0)

        assignments_data.each do |item|
          assignment = TeacherStudentAssignment.find_by(id: item[:assignment_id])
          unless assignment
            error_message = "Assignment #{item[:assignment_id]} not found"
            raise ActiveRecord::Rollback
          end

          unless assignment.status_scheduled?
            error_message = "Cannot reassign assignment #{assignment.id} with status '#{assignment.status}'. Only scheduled assignments can be reassigned."
            raise ActiveRecord::Rollback
          end

          target_teacher = StaffMember.find_by(id: item[:new_teacher_id])
          unless target_teacher
            error_message = "Target teacher #{item[:new_teacher_id]} not found"
            raise ActiveRecord::Rollback
          end

          # 1. Availability validation (FR-122 / FR-123)
          if target_teacher.unavailable_for_date?(assignment.scheduled_date, assignment.session_block_definition_id)
            error_message = "Target teacher #{target_teacher.full_name} is marked as unavailable for date #{assignment.scheduled_date} and block"
            raise ActiveRecord::Rollback
          end

          # 2. Capacity validation (FR-123)
          max_capacity = SessionScheduleConfig.instance.staff_to_student_capacity
          current_count = target_teacher.teacher_student_assignments
                                        .scheduled
                                        .where(scheduled_date: assignment.scheduled_date, session_block_definition_id: assignment.session_block_definition_id)
                                        .where.not(id: assignment.id)
                                        .count

          batch_key = [ target_teacher.id, assignment.scheduled_date, assignment.session_block_definition_id ]
          projected_count = current_count + batch_additions[batch_key] + 1

          if projected_count > max_capacity
            error_message = "Target teacher #{target_teacher.full_name} exceeds capacity of #{max_capacity} students for this session block"
            raise ActiveRecord::Rollback
          end

          # 3. Double-booking check for student
          student_conflict = TeacherStudentAssignment
            .scheduled
            .where(student_id: assignment.student_id, scheduled_date: assignment.scheduled_date, session_block_definition_id: assignment.session_block_definition_id)
            .where.not(id: assignment.id)
            .exists?

          if student_conflict
            error_message = "Student is already assigned to another teacher for this date and session block"
            raise ActiveRecord::Rollback
          end

          # Reassign
          assignment.teacher = target_teacher
          assignment.therapy_station_id = item[:therapy_station_id] if item[:therapy_station_id].present?
          assignment.therapy_room_id = item[:therapy_room_id] if item[:therapy_room_id].present?

          unless assignment.save
            error_message = assignment.errors.full_messages.join(", ")
            raise ActiveRecord::Rollback
          end

          batch_additions[batch_key] += 1
          reassigned_records << assignment
        end
      end

      return failure(error_message) if error_message.present?

      success(
        reassigned_count: reassigned_records.size,
        reassigned_assignments: reassigned_records
      )
    end

    private

    def normalize_assignments_data
      if params[:assignments].is_a?(Array)
        params[:assignments].map do |item|
          {
            assignment_id: item[:assignment_id] || item[:id],
            new_teacher_id: item[:new_teacher_id] || item[:target_teacher_id] || item[:teacher_id],
            therapy_station_id: item[:therapy_station_id],
            therapy_room_id: item[:therapy_room_id]
          }
        end
      elsif params[:assignment_ids].is_a?(Array) && (params[:new_teacher_id].present? || params[:target_teacher_id].present?)
        target_id = params[:new_teacher_id] || params[:target_teacher_id]
        params[:assignment_ids].map do |id|
          {
            assignment_id: id,
            new_teacher_id: target_id,
            therapy_station_id: params[:therapy_station_id],
            therapy_room_id: params[:therapy_room_id]
          }
        end
      elsif params[:assignment_id].present? && (params[:new_teacher_id].present? || params[:target_teacher_id].present?)
        [
          {
            assignment_id: params[:assignment_id],
            new_teacher_id: params[:new_teacher_id] || params[:target_teacher_id],
            therapy_station_id: params[:therapy_station_id],
            therapy_room_id: params[:therapy_room_id]
          }
        ]
      else
        []
      end
    end
  end
end
