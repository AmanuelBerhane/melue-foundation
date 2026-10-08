# frozen_string_literal: true

module Iups
  class FinalizeService < ApplicationService
    def initialize(iup:, finalized_by_user:)
      @iup = iup
      @finalized_by_user = finalized_by_user
    end

    def call
      validate_signatures_present
      validate_iup_complete

      ActiveRecord::Base.transaction do
        archive_previous_active_iup
        finalize_iup
        activate_student_goals
        transition_student_status
        log_finalization
      end

      success(iup: @iup.reload)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_signatures_present
      unless @iup.signatures_complete?
        raise ValidationError, "Both Program Director and Guardian signatures required"
      end
    end

    def validate_iup_complete
      validation_result = Iups::ValidateService.call(iup: @iup)

      unless validation_result.success?
        raise ValidationError, "IUP validation failed: #{validation_result.error[:errors].join(', ')}"
      end
    end

    def archive_previous_active_iup
      previous_iup = Iup.kept.lock.find_by(student: @iup.student, status: "active")

      return unless previous_iup

      previous_iup.update!(status: "archived")

      previous_iup.student_goals.kept.where(status: "active").update_all(
        status: "archived",
        updated_at: Time.current
      )
    end

    def finalize_iup
      @previous_status = @iup.status
      @iup.update!(
        status: "active",
        finalized_on: Date.current,
        finalized_by_user: @finalized_by_user
      )

      @iup.form_submission&.update!(status: "finalized")
    end

    def activate_student_goals
      @iup.student_goals.kept.update_all(
        status: "active",
        updated_at: Time.current
      )
    end

    def transition_student_status
      @iup.student.update!(status: "active_therapy")
      @iup.student.reload
    end

    def log_finalization
      AuditLog.create!(
        resource_type: "Iup",
        resource_id: @iup.id.to_s,
        action: "iup_finalized",
        user_id: @finalized_by_user.id,
        change_data: {
          previous_status: @previous_status,
          new_status: "active",
          student_id: @iup.student_id,
          finalized_on: @iup.finalized_on
        }
      )
    end

    class ValidationError < StandardError; end
  end
end
