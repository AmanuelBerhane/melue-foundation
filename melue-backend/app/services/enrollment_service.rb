class EnrollmentService < ApplicationService
  attr_reader :student, :params, :current_user

  def initialize(student = nil, params = {}, current_user = nil)
    @student = student || Student.new
    @params = params
    @current_user = current_user
  end

  def start_wizard
    # Check authentication
    if current_user.nil?
      return failure("Authentication required")
    end

    # Check permissions
    if current_user.respond_to?(:can?) && !current_user.can?(:create, :students)
      return failure("Insufficient permissions to create students")
    end

    # If student already has data, just return it
    if student.persisted?
      return success(student)
    end

    # Create a new student with minimal data to pass validations
    # In a real scenario, the first step would be filled in before saving
    # For the wizard flow, we want to save with default values
    student.status = "draft"

    # If the student has no data, we need to set default values
    # This allows the wizard to start without requiring all fields
    if student.new_record?
      # We'll use a transaction to ensure atomic save
      begin
        student.save!(validate: false)  # Skip validations for initial creation
        success(student)
      rescue => e
        failure("Failed to create student: #{e.message}")
      end
    else
      success(student)
    end
  end

  def update_step(step_number, step_params)
    return failure("Student not found") unless student.persisted?

    case step_number
    when 1
      student.assign_attributes(
        first_name: step_params[:first_name],
        middle_name: step_params[:middle_name],
        last_name: step_params[:last_name],
        date_of_birth: step_params[:date_of_birth],
        guardian_name: step_params[:guardian_name],
        guardian_phone: step_params[:guardian_phone],
        guardian_email: step_params[:guardian_email]
      )
    when 2
      student.assign_attributes(
        diagnosis: step_params[:diagnosis],
        program_type: step_params[:program_type],
        therapy_group: step_params[:therapy_group]
      )
    else
      return failure("Invalid step number")
    end

    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end

  def complete_enrollment
    return failure("Student not found") unless student.persisted?

    unless student.required_fields_present?
      return failure("Missing required information")
    end

    if student.age_warning_for_group?
      return failure("Age (#{student.age}) may not be appropriate for #{student.therapy_group} group")
    end

    unless student.required_documents_attached?
      return failure("Missing required documents: Birth Certificate, Diagnosis Paper, and Agreement")
    end

    unless student.headshot_photo.attached?
      return failure("Headshot photo is required")
    end

    Student.transaction do
      student.status = "in_assessment"
      student.enrolled_at = Time.current
      student.assessment_started_at = Time.current

      if student.save!
        success(student)
      else
        failure(student.errors.full_messages.join(", "))
      end
    end
  rescue => e
    failure("Failed to complete enrollment: #{e.message}")
  end

  def save_draft
    return failure("Student not found") unless student.persisted?

    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end

  def attach_document(document_type, file)
    return failure("Student not found") unless student.persisted?

    existing = student.documents.find_by(document_type: document_type)
    if existing
      return failure("Document type '#{document_type}' already uploaded. Please delete or replace it.")
    end

    doc = student.documents.build(
      document_type: document_type
    )

    doc.file.attach(file)

    if doc.save
      success(doc)
    else
      failure(doc.errors.full_messages.join(", "))
    end
  end

  def attach_headshot(file)
    return failure("Student not found") unless student.persisted?

    student.headshot_photo.attach(file)
    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end

  def attach_baseline_video(file)
    return failure("Student not found") unless student.persisted?

    student.baseline_video.attach(file)
    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end
end
