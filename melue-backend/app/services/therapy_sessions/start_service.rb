# frozen_string_literal: true

module TherapySessions
  # Creates a new TherapySession from a scheduled TeacherStudentAssignment.
  #
  # Business rules enforced (FR-088, FR-090):
  #   - Caller must be the assigned teacher for the assignment
  #   - Assignment must be scheduled (not cancelled/completed)
  #   - Assignment must be for today's date
  #   - Exactly two student assignments must exist for that teacher/block/date
  #   - Idempotent: returns the existing in_progress session if one already exists
  #   - Creates the session and both SessionParticipants atomically
  class StartService < ApplicationService
    # @param assignment [TeacherStudentAssignment] the teacher's own assignment for today's block
    # @param staff_member [StaffMember] the authenticated teacher starting the session
    def initialize(assignment:, staff_member:)
      @assignment = assignment
      @staff_member = staff_member
    end

    def call
      return failure("Assignment not found") unless @assignment
      return failure("You are not the assigned teacher for this block") unless assigned_teacher?
      return failure("Assignment is not scheduled") unless @assignment.status_scheduled?
      return failure("Assignment is not for today") unless @assignment.scheduled_date == Date.current

      # Idempotent: return existing active session if already started
      existing = find_existing_session
      return success(existing) if existing

      # Fetch all scheduled assignments for this teacher/block/date to build participants
      sibling_assignments = fetch_sibling_assignments
      return failure("A session requires exactly 2 student assignments; found #{sibling_assignments.count}") unless sibling_assignments.count == 2

      session = create_session!(sibling_assignments)
      success(session)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    end

    private

    def assigned_teacher?
      @assignment.teacher_id == @staff_member.id
    end

    def find_existing_session
      TherapySession
        .in_progress
        .joins(:session_participants)
        .where(
          teacher_id: @staff_member.id,
          session_block_definition_id: @assignment.session_block_definition_id,
          session_participants: { teacher_student_assignment_id: @assignment.id }
        )
        .first
    end

    def fetch_sibling_assignments
      TeacherStudentAssignment
        .scheduled
        .for_teacher(@staff_member.id)
        .for_block(@assignment.session_block_definition_id)
        .for_today
        .order(:created_at)
    end

    def create_session!(sibling_assignments)
      ActiveRecord::Base.transaction do
        session = TherapySession.create!(
          teacher: @staff_member,
          session_block_definition_id: @assignment.session_block_definition_id,
          therapy_station_id: @assignment.therapy_station_id,
          therapy_room_id: @assignment.therapy_room_id,
          status: :in_progress,
          started_at: Time.current
        )

        # First assignment → active card, second → secondary card (FR-090)
        card_positions = [ :active, :secondary ]
        sibling_assignments.each_with_index do |sibling, index|
          SessionParticipant.create!(
            therapy_session: session,
            student_id: sibling.student_id,
            teacher_student_assignment: sibling,
            card_position: card_positions[index]
          )
        end

        session
      end
    end
  end
end
