# frozen_string_literal: true

module SessionSummaries
  # Finalizes the summary and completes the therapy session atomically in a single transaction.
  class SubmitService < ApplicationService
    def initialize(session:, qualitative_notes: nil)
      @session           = session
      @qualitative_notes = qualitative_notes
    end

    def call
      summary = @session.session_summary || @session.build_session_summary

      # Idempotent: if already submitted or reviewed, return success without mutating submitted_at
      if summary.persisted? && (summary.status_submitted? || summary.status_reviewed?)
        return success(summary)
      end

      ActiveRecord::Base.transaction do
        summary.qualitative_notes = @qualitative_notes if @qualitative_notes.present?
        summary.status            = :submitted
        summary.submitted_at      = Time.current
        summary.save!

        @session.status   = :completed
        @session.ended_at = Time.current if @session.ended_at.blank?
        @session.save!
      end

      success(summary)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      failure(e.message)
    end
  end
end
