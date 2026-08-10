# frozen_string_literal: true

class Student < ApplicationRecord
  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :session_participants, dependent: :restrict_with_error
  has_many :iups, dependent: :restrict_with_error
  has_many :student_goals, dependent: :restrict_with_error
  has_many :student_guardians, dependent: :restrict_with_error
  has_many :guardians, through: :student_guardians

  has_one_attached :headshot

  enum :program_type, { regular: "regular", pulled_out: "pulled_out" }, prefix: true
  enum :therapy_group, { basic: "basic", functional_living: "functional_living" }, prefix: true
  enum :status, {
    registered: "registered",
    in_assessment: "in_assessment",
    assessment_complete: "assessment_complete",
    ready_for_iup: "ready_for_iup",
    active_therapy: "active_therapy",
    withdrawn: "withdrawn",
    discharged: "discharged"
  }, prefix: true

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :date_of_birth, presence: true
  validates :program_type, presence: true
  validates :therapy_group, presence: true
  validates :status, presence: true

  # ── Scopes ──────────────────────────────────────────────────────────────────

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

  # ── Instance Methods ────────────────────────────────────────────────────────

  def full_name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  # Returns the student's age in whole years, calculated from date_of_birth
  def age
    return nil unless date_of_birth

    today = Date.current
    age = today.year - date_of_birth.year
    age -= 1 if today < date_of_birth + age.years
    age
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
  # Result: [ { station: { id, name }, goals: [ { id, name, progress_percent } ] } ]
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
end
