# frozen_string_literal: true

module Director
  # SCR-DIR-002 / FR-117 — removes teacher-student assignments from a session
  # block on a date. Optionally narrowed to one teacher and/or specific students.
  #
  # Assignment rows are deleted (not discarded) because the unique index on
  # (student, block, date) would otherwise block re-assigning the student.
  # Assignments already attached to a started therapy session are kept so
  # trial history is never orphaned; they are reported back as `skipped`.
  class ClearBlockService < ApplicationService
    def initialize(block:, date:, teacher_id: nil, student_ids: nil)
      @block = block
      @date = date
      @teacher_id = teacher_id
      @student_ids = Array(student_ids).compact_blank.presence
    end

    def call
      return failure("Session block not found", :not_found) unless @block

      removed = []
      skipped = []

      TeacherStudentAssignment.transaction do
        scope.includes(:session_participant).find_each do |assignment|
          if assignment.session_participant
            skipped << skipped_entry(assignment)
          else
            assignment.destroy!
            removed << assignment.student_id
          end
        end
      end

      success(removed_count: removed.size, removed_student_ids: removed, skipped: skipped)
    end

    private

    def scope
      relation = TeacherStudentAssignment.for_date(@date).for_block(@block.id)
      relation = relation.for_teacher(@teacher_id) if @teacher_id.present?
      relation = relation.where(student_id: @student_ids) if @student_ids
      relation
    end

    def skipped_entry(assignment)
      {
        assignment_id: assignment.id,
        student_id: assignment.student_id,
        student_name: assignment.student.full_name,
        reason: "Student is already in a started therapy session for this block"
      }
    end
  end
end
