# frozen_string_literal: true

module Sessions
  # Swaps the Active (0) and Secondary (1) card positions for a therapy session.
  # O(1) operation — does NOT mutate teacher_student_assignments (FR-096).
  #
  # PostgreSQL checks unique constraints per-row even within a single UPDATE,
  # so a direct CASE swap would violate idx_sp_unique_card_position_per_session.
  # We use a three-step approach with a temporary sentinel value (-1) inside
  # a transaction to avoid the constraint collision.
  class SwapActiveStudent < ApplicationService
    TEMP_POSITION = -1

    def initialize(therapy_session:)
      @session = therapy_session
    end

    def call
      return failure("Session is not in progress") unless @session.status_in_progress?

      participants = @session.session_participants.order(:card_position).to_a
      return failure("Need exactly two participants to swap") unless participants.size == 2

      session_id = @session.id

      ActiveRecord::Base.transaction do
        # Step 1: Move active (0) → temp (-1)
        SessionParticipant.where(therapy_session_id: session_id, card_position: 0)
                          .update_all(card_position: TEMP_POSITION)

        # Step 2: Move secondary (1) → active (0)
        SessionParticipant.where(therapy_session_id: session_id, card_position: 1)
                          .update_all(card_position: 0)

        # Step 3: Move temp (-1) → secondary (1)
        SessionParticipant.where(therapy_session_id: session_id, card_position: TEMP_POSITION)
                          .update_all(card_position: 1)
      end

      success(@session.reload)
    rescue ActiveRecord::RecordNotUnique => e
      failure("Failed to swap: #{e.message}")
    end
  end
end
