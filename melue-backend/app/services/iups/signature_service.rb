# frozen_string_literal: true

module Iups
  class SignatureService < ApplicationService
    def initialize(iup:, signer_user:, signer_role:, signature_evidence: nil)
      @iup = iup
      @signer_user = signer_user
      @signer_role = signer_role
      @signature_evidence = signature_evidence
    end

    def call
      validate_signer_authorization

      ActiveRecord::Base.transaction do
        capture_signature
        send_guardian_notification if @signer_role == "program_director"
        log_signature
      end

      success(signature: @signature)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_signer_authorization
      case @signer_role
      when "program_director"
        unless has_program_director_role?
          raise ValidationError, "User must have Program Director role"
        end
      when "guardian"
        unless is_students_guardian?
          raise ValidationError, "User must be associated guardian for this student"
        end
      else
        raise ValidationError, "Invalid signer role: #{@signer_role}"
      end
    end

    def capture_signature
      @signature = IupSignature.find_or_initialize_by(
        iup: @iup,
        signer_role: @signer_role
      )

      @signature.update!(
        signer_user: @signer_user,
        signed_at: Time.current,
        signature_evidence: @signature_evidence || build_signature_evidence
      )
    end

    def send_guardian_notification
      guardian = @iup.student.student_guardians.find_by(is_primary_contact: true)&.guardian

      return unless guardian&.user

      Notification.create!(
        recipient: guardian.user,
        type: "IupSignatureRequest",
        payload_reference: {
          iup_id: @iup.id,
          student_name: @iup.student.full_name
        }.to_json
      )
    rescue StandardError => e
      Rails.logger.error("Failed to send guardian notification: #{e.message}")
    end

    def log_signature
      AuditLog.create!(
        resource_type: "IupSignature",
        resource_id: @signature.id.to_s,
        action: "signature_captured",
        user_id: @signer_user.id,
        change_data: {
          iup_id: @iup.id,
          signer_role: @signer_role
        }
      )
    end

    def has_program_director_role?
      @signer_user.role_assignments.where(revoked_at: nil).joins(:role).exists?(
        roles: { name: "Program Director" }
      )
    end

    def is_students_guardian?
      Guardian.joins(:student_guardians).exists?(
        user_id: @signer_user.id,
        student_guardians: { student_id: @iup.student_id }
      )
    end

    def build_signature_evidence
      {
        timestamp: Time.current.iso8601
      }.to_json
    end

    class ValidationError < StandardError; end
  end
end
