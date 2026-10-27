# frozen_string_literal: true

module Students
  # Creates a new student with status "in_assessment" (FR-028).
  # Validates that the student's age is appropriate for the selected therapy group:
  #   - Basic Therapy: ages 3–12
  #   - Functional Living Skills: ages 13–19
  class RegisterService < ApplicationService
    AGE_RANGES = {
      "basic" => (3..12),
      "functional_living" => (13..19)
    }.freeze

    # @param params [Hash] student attributes (including optional :headshot file, :custom_fields)
    # @param current_user [User] the authenticated user
    def initialize(params:, current_user:)
      @params = params
      @current_user = current_user
    end

    def call
      staff = staff_member
      return failure("Staff profile required") unless staff

      student = Student.new(student_params)
      student.status = @params[:status].presence || :in_assessment
      student.enrolled_at = @params[:enrolled_at].presence || Time.current

      age_error = validate_age_for_therapy_group(student)
      return failure(age_error) if age_error

      attach_headshot(student)
      attach_baseline_video(student)

      if student.save
        attach_documents(student)
        success(student)
      else
        failure(student.errors.full_messages.join(", "))
      end
    end

    private

    def staff_member
      @staff_member ||= StaffMember.find_by(user_id: @current_user.id)
    end

    def student_params
      attrs = @params.slice(
        :first_name, :middle_name, :last_name,
        :date_of_birth, :program_type, :therapy_group,
        :diagnosis, :guardian_name, :guardian_phone,
        :guardian_email, :enrolled_at, :student_id
      )
      attrs[:student_id] ||= @params[:studentId] if @params[:studentId].present?
      attrs[:custom_fields] = @params[:custom_fields] if @params[:custom_fields].present?
      attrs
    end

    def validate_age_for_therapy_group(student)
      return nil unless student.date_of_birth.present? && student.therapy_group.present?

      age = student.age
      return nil unless age

      valid_range = AGE_RANGES[student.therapy_group]
      return nil unless valid_range

      unless valid_range.include?(age)
        group_label = student.therapy_group == "basic" ? "Basic Therapy (ages 3–12)" : "Functional Living Skills (ages 13–19)"
        return "Age #{age} is not appropriate for #{group_label}"
      end

      nil
    end

    def build_file_io(file, default_filename:, default_content_type:)
      return nil unless file.present?

      if file.is_a?(ActiveStorage::Blob)
        file
      elsif file.is_a?(String) && file.start_with?("data:")
        match = file.match(/\Adata:([^;]+);base64,(.+)\z/m)
        if match
          content_type = match[1]
          data = Base64.decode64(match[2])
          ext = Rack::Mime::MIME_TYPES.invert[content_type] || ".bin"
          filename = default_filename.end_with?(ext) ? default_filename : "#{File.basename(default_filename, '.*')}#{ext}"
          { io: StringIO.new(data), filename: filename, content_type: content_type }
        else
          nil
        end
      elsif file.respond_to?(:read) || file.respond_to?(:tempfile)
        {
          io: file.respond_to?(:tempfile) ? file.tempfile : file,
          filename: file.respond_to?(:original_filename) ? file.original_filename : default_filename,
          content_type: file.respond_to?(:content_type) ? file.content_type : default_content_type
        }
      elsif file.is_a?(Hash) && file[:io].present?
        file
      else
        nil
      end
    end

    def attach_headshot(student)
      file = @params[:headshot] || @params[:photo] || @params[:enr_headshot] || @params[:photoUrl] || @params[:photo_url]
      return unless file.present?

      target = build_file_io(file, default_filename: "headshot.jpg", default_content_type: "image/jpeg")
      return unless target.present?

      blob = target.is_a?(ActiveStorage::Blob) ? target : ActiveStorage::Blob.create_and_upload!(
        io: target[:io],
        filename: target[:filename],
        content_type: target[:content_type]
      )

      student.headshot.attach(blob)
      student.headshot_photo.attach(blob)
    rescue => e
      Rails.logger.warn("Failed to attach headshot: #{e.message}")
    end

    def attach_baseline_video(student)
      file = @params[:baseline_video] || @params[:baselineVideo] || @params[:enr_baseline_video] || @params[:video] || @params[:videoUrl]
      return unless file.present?

      target = build_file_io(file, default_filename: "baseline_video.mp4", default_content_type: "video/mp4")
      return unless target.present?

      blob = target.is_a?(ActiveStorage::Blob) ? target : ActiveStorage::Blob.create_and_upload!(
        io: target[:io],
        filename: target[:filename],
        content_type: target[:content_type]
      )

      student.baseline_video.attach(blob)
    rescue => e
      Rails.logger.warn("Failed to attach baseline video: #{e.message}")
    end

    def attach_documents(student)
      # Birth certificate
      bc_file = @params[:birth_certificate] || @params[:birthCertificate] || @params[:enr_birth_certificate]
      attach_single_document(student, bc_file, "birth_certificate", "birth_certificate.pdf", "application/pdf")

      # Medical diagnosis paper
      dp_file = @params[:diagnosis_paper] || @params[:diagnosisPaper] || @params[:enr_diagnosis_paper]
      attach_single_document(student, dp_file, "diagnosis_paper", "diagnosis_paper.pdf", "application/pdf")

      # Agreement
      ag_file = @params[:agreement] || @params[:enr_agreement] || @params[:agreement_document] || @params[:agreementDocument]
      attach_single_document(student, ag_file, "agreement", "agreement.pdf", "application/pdf")
    end

    def attach_single_document(student, file, doc_type, default_name, default_type)
      return unless file.present?

      target = build_file_io(file, default_filename: default_name, default_content_type: default_type)
      return unless target.present?

      blob = target.is_a?(ActiveStorage::Blob) ? target : ActiveStorage::Blob.create_and_upload!(
        io: target[:io],
        filename: target[:filename],
        content_type: target[:content_type]
      )

      doc = student.documents.find_or_initialize_by(document_type: doc_type)
      doc.file.attach(blob)
      doc.description ||= "#{doc_type.humanize} attached during enrollment"
      doc.save!
    rescue => e
      Rails.logger.warn("Failed to attach document #{doc_type}: #{e.message}")
    end
  end
end
