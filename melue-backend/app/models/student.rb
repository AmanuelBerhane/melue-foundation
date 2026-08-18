class Student < ApplicationRecord
  include Discard::Model

  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :session_participants, dependent: :restrict_with_error
  has_many :iups, dependent: :restrict_with_error
  has_many :student_goals, dependent: :restrict_with_error
  has_many :student_guardians, dependent: :restrict_with_error
  has_many :guardians, through: :student_guardians

  has_many :assessment_cycles, dependent: :restrict_with_error
  has_many :behavior_incidents, dependent: :restrict_with_error

  has_one_attached :headshot

  has_one_attached :headshot_photo
  has_one_attached :baseline_video
  has_many_attached :documents

  has_many :documents, class_name: "StudentDocument", dependent: :destroy

  enum :program_type, { regular: "regular", pulled_out: "pulled_out" }, prefix: true
  enum :therapy_group, { basic: "basic", functional_living: "functional_living" }, prefix: true


  enum :status, {

    draft: "draft",
    pending_review: "pending_review",

    registered: "registered",
    in_assessment: "in_assessment",

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

  scope :search_by_name, ->(query) {
    return all if query.blank?

    sanitized = "%#{sanitize_sql_like(query)}%"
    where("first_name ILIKE :q OR last_name ILIKE :q", q: sanitized)
  }

  scope :by_program_type, ->(type) {
    return all if type.blank?

    where(program_type: type)
  }

  scope :by_therapy_group, ->(group) {
    return all if group.blank?

    where(therapy_group: group)
  }

  def full_name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  def age
    return nil unless date_of_birth

    today = Date.current
    age = today.year - date_of_birth.year
    age -= 1 if today < date_of_birth + age.years
    age
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

  def required_fields_present?
    [ first_name, last_name, date_of_birth, guardian_name, guardian_phone,
     program_type, therapy_group ].all?(&:present?)
  end

  def required_documents_attached?
    required_types = [ "birth_certificate", "diagnosis_paper", "agreement" ]
    (documents.pluck(:document_type) & required_types).size == required_types.size
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

  # Returns a goals summary: up to 2 active/in_progress goals per station
  def current_goals_summary
    active_goals = student_goals
      .includes(:goal, :therapy_station)
      .where(status: %w[active in_progress])

    active_goals
      .group_by(&:therapy_station)
      .map do |station, goals|
        {
          station: { id: station.id, name: station.name },
          goals: goals.first(2).map do |sg|
            {
              id: sg.id,
              goal_name: sg.goal_name,
              progress_percent: sg.progress_percent.to_f
            }
          end
        }
      end
  end

  def assigned_to_teacher_for_block?(teacher_id, date, block_id)
    TeacherStudentAssignment
      .scheduled
      .where(student_id: id)
      .where(teacher_id: teacher_id)
      .where(scheduled_date: date)
      .where(session_block_definition_id: block_id)
      .exists?
  end

  private

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
