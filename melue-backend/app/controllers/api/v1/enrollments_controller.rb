class Api::V1::EnrollmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_current_user
  before_action :authorize_enrollment_access, except: [ :complete, :save_draft ]
  before_action :load_student, only: [ :show, :update_step, :complete, :save_draft, :attach_document, :upload_photo, :upload_video, :remove_photo, :remove_video ]

  # @oas_include
  # @summary Start Enrollment Wizard
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @response Created (201) [Hash{ id: Integer, status: String, message: String }]
  def create
    result = EnrollmentService.new(nil, {}, current_user).start_wizard

    if result.success?
      render json: {
        id: result.data.id,
        status: result.data.status,
        message: "Enrollment wizard started successfully"
      }, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Update enrollment step
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  # @parameter step(query) [!Integer] Step number (1-3)
  # @request_body Step data [Hash{ ... }]
  def update_step
    result = EnrollmentService.new(@student, enrollment_params, current_user).update_step(params[:step].to_i, enrollment_params)

    if result.success?
      render json: {
        student: result.data,
        step_complete: true,
        next_step: params[:step].to_i + 1,
        required_fields: required_fields_for_step(params[:step].to_i + 1)
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Complete enrollment
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  def complete
    result = EnrollmentService.new(@student, {}, current_user).complete_enrollment

    if result.success?
      render json: {
        student: result.data,
        status: result.data.status,
        enrolled_at: result.data.enrolled_at,
        message: "Enrollment completed successfully"
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Save enrollment draft
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  def save_draft
    result = EnrollmentService.new(@student, enrollment_params, current_user).save_draft

    if result.success?
      render json: {
        student: result.data,
        status: result.data.status,
        message: "Draft saved successfully"
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Attach document to enrollment
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  # @parameter document_type(query) [!String] Type of document (birth_certificate, diagnosis_paper, agreement)
  # @parameter description(query) [String] Optional description
  # @request_body file (multipart/form-data) [!File] Document file
  def attach_document
    service = StudentDocumentService.new(@student, current_user)
    result = service.upload_document(
      params[:document_type],
      params[:file],
      description: params[:description]
    )

    if result.success?
      render json: {
        document: result.data,
        message: "Document attached successfully"
      }, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Upload headshot photo
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  # @request_body photo (multipart/form-data) [!File] Headshot photo
  def upload_photo
    service = StudentDocumentService.new(@student, current_user)
    result = service.upload_photo(params[:photo])

    if result.success?
      render json: {
        photo_url: url_for(result.data.headshot_photo),
        message: "Photo uploaded successfully"
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Upload baseline video
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  # @request_body video (multipart/form-data) [File] Baseline video (optional)
  def upload_video
    service = StudentDocumentService.new(@student, current_user)
    result = service.upload_video(params[:video])

    if result.success?
      render json: {
        video_url: url_for(result.data.baseline_video),
        message: "Video uploaded successfully"
      }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Remove headshot photo
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  def remove_photo
    service = StudentDocumentService.new(@student, current_user)
    result = service.remove_photo

    if result.success?
      render json: { message: "Photo removed successfully" }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Remove baseline video
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  def remove_video
    service = StudentDocumentService.new(@student, current_user)
    result = service.remove_video

    if result.success?
      render json: { message: "Video removed successfully" }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Get enrollment status
  # @tags Enrollments
  # @auth [bearer_jwt]
  #
  # @parameter id(path) [!Integer] Student ID
  def show
    render json: {
      student: @student,
      status: @student.status,
      enrolled_at: @student.enrolled_at,
      documents: @student.documents.map { |doc|
        {
          id: doc.id,
          type: doc.document_type,
          filename: doc.file.filename.to_s,
          url: url_for(doc.file)
        }
      },
      has_photo: @student.headshot_photo.attached?,
      has_video: @student.baseline_video.attached?,
      photo_url: @student.headshot_photo.attached? ? url_for(@student.headshot_photo) : nil,
      video_url: @student.baseline_video.attached? ? url_for(@student.baseline_video) : nil
    }
  end

  private

  def load_student
    @student = Student.find(params[:id])
  end

  def authorize_enrollment_access
    require_staff_member!
  end

  def enrollment_params
    params.require(:enrollment).permit(
      :first_name, :middle_name, :last_name,
      :date_of_birth, :diagnosis,
      :guardian_name, :guardian_phone, :guardian_email,
      :program_type, :therapy_group
    )
  end

  def required_fields_for_step(step)
    case step
    when 1
      [ "first_name", "last_name", "date_of_birth", "guardian_name", "guardian_phone" ]
    when 2
      [ "diagnosis", "program_type", "therapy_group" ]
    when 3
      [ "birth_certificate", "diagnosis_paper", "agreement", "headshot_photo" ]
    else
      []
    end
  end
end
