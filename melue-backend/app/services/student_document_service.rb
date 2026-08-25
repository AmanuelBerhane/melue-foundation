class StudentDocumentService < ApplicationService
  attr_reader :student, :current_user

  def initialize(student, current_user)
    @student = student
    @current_user = current_user
  end

  def upload_document(document_type, file, description: nil)
    return failure("Student not found") unless student.persisted?

    # Check if document type already exists
    existing = student.documents.find_by(document_type: document_type)
    if existing
      return failure("Document type '#{document_type}' already uploaded. Please delete or replace it.")
    end

    doc = student.documents.build(
      document_type: document_type,
      description: description
    )

    doc.file.attach(file)

    if doc.save
      success(doc)
    else
      failure(doc.errors.full_messages.join(", "))
    end
  end

  def delete_document(document_id)
    doc = student.documents.find_by(id: document_id)
    return failure("Document not found") unless doc

    # Check if this is a required document
    if doc.document_type.in?(%w[birth_certificate diagnosis_paper agreement])
      return failure("Cannot delete '#{doc.document_type}' - it's required for enrollment")
    end

    doc.destroy
    success(doc)
  end

  def upload_photo(file)
    return failure("Student not found") unless student.persisted?

    # Remove existing photo if it exists
    student.headshot_photo.purge if student.headshot_photo.attached?

    student.headshot_photo.attach(file)
    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end

  def upload_video(file)
    return failure("Student not found") unless student.persisted?

    # Remove existing video if it exists
    student.baseline_video.purge if student.baseline_video.attached?

    student.baseline_video.attach(file)
    if student.save
      success(student)
    else
      failure(student.errors.full_messages.join(", "))
    end
  end

  def remove_photo
    return failure("Student not found") unless student.persisted?

    student.headshot_photo.purge
    success(student)
  end

  def remove_video
    return failure("Student not found") unless student.persisted?

    student.baseline_video.purge
    success(student)
  end
end
