class Student < ApplicationRecord
  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :session_participants, dependent: :restrict_with_error
  has_many :iups, dependent: :restrict_with_error
  has_many :student_goals, dependent: :restrict_with_error

  has_many :documents, class_name: "StudentDocument", dependent: :destroy
  has_one_attached :headshot_photo
  has_one_attached :baseline_video

  enum :program_type, { regular: "regular", pulled_out: "pulled_out" }, prefix: true
  enum :therapy_group, { basic: "basic", functional_living: "functional_living" }, prefix: true

  enum :status, {
    # Enrollment wizard statuses
    draft: "draft",
    pending_review: "pending_review",

    # Assessment phase
    in_assessment: "In Assessment",
    assessment_complete: "assessment_complete",
    ready_for_iup: "ready_for_iup",

    # Active therapy
    active_therapy: "active_therapy",
    active: "active",

    # Exit statuses
    withdrawn: "withdrawn",
    discharged: "discharged",
    archived: "archived"
  }, prefix: true

  validates :first_name, :last_name, :date_of_birth, presence: true
  validates :program_type, :therapy_group, presence: true
  validates :status, presence: true

  # Guardian fields
  validates :guardian_name, :guardian_phone, presence: true
  validates :guardian_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  validate :photo_format_and_size, if: -> { headshot_photo.attached? }
  validate :video_format_and_size, if: -> { baseline_video.attached? }


  # Full name
  def full_name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  # Age calculation
  def age
    return nil unless date_of_birth
    ((Date.current - date_of_birth).to_i / 365.25).floor
  end

  # Age warning for therapy group
  def age_warning_for_group?
    return false unless therapy_group && age

    case therapy_group
    when "basic"
      age < 3 || age > 12
    when "functional_living"
      age < 13 || age > 19
    end
  end

  # Enrollment complete check
  def enrollment_complete?
    required_fields_present? && required_documents_attached? && headshot_photo.attached?
  end

  # Returns the single active IUP for this student
  def active_iup
    iups.find_by(status: "active")
  end

  # Returns active student goals for a specific station
  def active_goals_for_station(therapy_station_id)
    student_goals.where(therapy_station_id: therapy_station_id, status: %w[active in_progress])
  end

  private

  def required_fields_present?
    [ first_name, last_name, date_of_birth, guardian_name, guardian_phone,
     program_type, therapy_group ].all?(&:present?)
  end

  def required_documents_attached?
    required_types = [ "birth_certificate", "diagnosis_paper", "agreement" ]
    (documents.pluck(:document_type) & required_types).size == required_types.size
  end

  def photo_format_and_size
    unless headshot_photo.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:headshot_photo, "must be a JPEG, PNG, or WEBP image")
    end

    if headshot_photo.byte_size > 10.megabytes
      errors.add(:headshot_photo, "size must be less than 10MB")
    end
  end

  def video_format_and_size
    unless baseline_video.content_type.in?(%w[video/mp4 video/quicktime])
      errors.add(:baseline_video, "must be MP4 or MOV format")
    end

    if baseline_video.byte_size > 100.megabytes
      errors.add(:baseline_video, "size must be less than 100MB")
    end
  end
end
