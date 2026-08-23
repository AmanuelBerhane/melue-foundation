# frozen_string_literal: true

module Iups
  class CreateService < ApplicationService
    def initialize(student:, assessment_cycle:, current_user:)
      @student = student
      @assessment_cycle = assessment_cycle
      @current_user = current_user
    end

    def call
      validate_preconditions
      
      ActiveRecord::Base.transaction do
        create_draft_iup
        create_form_submission
        populate_assessment_summary
      end
      
      success(iup: @iup.reload)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_preconditions
      unless @assessment_cycle&.status_reviewed?
        raise ValidationError, "Assessment cycle must be completed and reviewed before creating IUP"
      end
      
      if Iup.where(student: @student, status: "draft").exists?
        raise ValidationError, "Student already has a draft IUP"
      end
    end

    def create_draft_iup
      @iup = Iup.create!(
        student: @student,
        assessment_cycle: @assessment_cycle,
        status: "draft",
        created_by_user: @current_user
      )
    end

    def create_form_submission
      form_config = FormConfiguration.find_by(form_type: "iup", is_default: true)
      
      raise ValidationError, "No default IUP form configuration found" unless form_config
      
      FormSubmission.create!(
        submittable: @iup,
        form_configuration: form_config,
        status: "draft",
        values: {}
      )
    end

    def populate_assessment_summary
      summary_result = Iups::AssessmentSummaryBuilder.call(assessment_cycle: @assessment_cycle)
      
      if summary_result.success?
        @iup.form_submission.update!(
          values: { "assessment_summary" => summary_result.data }
        )
      end
    end

    class ValidationError < StandardError; end
  end
end
