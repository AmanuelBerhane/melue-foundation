# frozen_string_literal: true

module SessionSummaries
  class ReviewService < ApplicationService
    def initialize(summary:, reviewed_by_user:)
      @summary          = summary
      @reviewed_by_user = reviewed_by_user
    end

    def call
      if @summary.status_reviewed?
        return success(@summary)
      end

      unless @summary.status_submitted?
        return failure("Only submitted summaries can be reviewed")
      end

      ActiveRecord::Base.transaction do
        @summary.status            = :reviewed
        @summary.reviewed_by_user  = @reviewed_by_user
        @summary.reviewed_at       = Time.current
        @summary.save!
      end

      success(@summary)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      failure(e.message)
    end
  end
end
