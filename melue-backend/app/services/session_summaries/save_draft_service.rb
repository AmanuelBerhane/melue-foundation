  # frozen_string_literal: true

module SessionSummaries
  class SaveDraftService < ApplicationService
    def initialize(session:, qualitative_notes:)
      @session           = session
      @qualitative_notes = qualitative_notes
    end

    def call
      summary = @session.session_summary || @session.build_session_summary

      if summary.persisted? && (summary.status_submitted? || summary.status_reviewed?)
        return failure("This summary cannot be modified")
      end

      summary.qualitative_notes = @qualitative_notes
      summary.status            = :draft

      if summary.save
        success(summary)
      else
        failure(summary.errors.full_messages.join(", "))
      end
    end
  end
end
