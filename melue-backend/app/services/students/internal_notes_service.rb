# frozen_string_literal: true

module Students
  # Service for managing Director-only internal student notes (FR-135).
  # Enforces that only Director / Administrator roles can access or author internal notes.
  # These notes are strictly forbidden from parent-facing and teacher-facing API endpoints.
  class InternalNotesService < ApplicationService
    # ── Class-level delegators ──────────────────────────────────────────────

    def self.list(student_id:, current_user:)
      new.list(student_id: student_id, current_user: current_user)
    end

    def self.create(student_id:, current_user:, params:)
      new.create(student_id: student_id, current_user: current_user, params: params)
    end

    def self.update(student_id:, note_id:, current_user:, params:)
      new.update(student_id: student_id, note_id: note_id, current_user: current_user, params: params)
    end

    def self.destroy(student_id:, note_id:, current_user:)
      new.destroy(student_id: student_id, note_id: note_id, current_user: current_user)
    end

    # ── Instance methods ────────────────────────────────────────────────────

    def list(student_id:, current_user:)
      return failure("Forbidden: Director or Administrator access required", :forbidden) unless authorized?(current_user)

      student = Student.find_by(id: student_id)
      return failure("Student not found", :not_found) unless student

      notes = student.internal_student_notes
                     .includes(author: [:staff_member, :roles])
                     .order(recorded_at: :desc)
      success(notes)
    rescue StandardError => e
      failure(e.message)
    end

    def create(student_id:, current_user:, params:)
      return failure("Forbidden: Director or Administrator access required", :forbidden) unless authorized?(current_user)

      student = Student.find_by(id: student_id)
      return failure("Student not found", :not_found) unless student

      content = params[:content].to_s.strip
      return failure("Content can't be blank", :unprocessable_entity) if content.blank?

      recorded_at = params[:recorded_at].present? ? Time.zone.parse(params[:recorded_at].to_s) : Time.current

      note = student.internal_student_notes.create!(
        author: current_user,
        content: content,
        recorded_at: recorded_at
      )

      success(note)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "), :unprocessable_entity)
    rescue StandardError => e
      failure(e.message)
    end

    def update(student_id:, note_id:, current_user:, params:)
      return failure("Forbidden: Director or Administrator access required", :forbidden) unless authorized?(current_user)

      student = Student.find_by(id: student_id)
      return failure("Student not found", :not_found) unless student

      note = student.internal_student_notes.find_by(id: note_id)
      return failure("Note not found", :not_found) unless note

      content = params[:content].to_s.strip
      return failure("Content can't be blank", :unprocessable_entity) if content.blank?

      update_attrs = { content: content }
      update_attrs[:recorded_at] = Time.zone.parse(params[:recorded_at].to_s) if params[:recorded_at].present?

      note.update!(update_attrs)
      success(note)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "), :unprocessable_entity)
    rescue StandardError => e
      failure(e.message)
    end

    def destroy(student_id:, note_id:, current_user:)
      return failure("Forbidden: Director or Administrator access required", :forbidden) unless authorized?(current_user)

      student = Student.find_by(id: student_id)
      return failure("Student not found", :not_found) unless student

      note = student.internal_student_notes.find_by(id: note_id)
      return failure("Note not found", :not_found) unless note

      note.destroy!
      success({ message: "Note deleted successfully" })
    rescue StandardError => e
      failure(e.message)
    end

    private

    def authorized?(user)
      return false unless user

      user.has_role?(Role::Names::DIRECTOR) ||
        user.has_role?(Role::Names::PROGRAM_DIRECTOR) ||
        user.has_role?(Role::Names::INSTITUTIONAL_ADMIN) ||
        user.has_role?(Role::Names::SYSTEM_ADMIN) ||
        user.has_role?(:system_admin) ||
        user.has_role?(:institutional_admin) ||
        user.has_role?("Director") ||
        user.has_role?("Program Director")
    end
  end
end
