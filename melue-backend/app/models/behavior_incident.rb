# app/models/behavior_incident.rb
class BehaviorIncident < ApplicationRecord
  include Discard::Model

  # Associations
  belongs_to :student
  belongs_to :staff_member, optional: true
  belongs_to :therapy_session, optional: true
  belongs_to :student_goal, optional: true

  # Enums
  enum :frequency, {
    rarely: 0,
    occasionally: 1,
    frequently: 2,
    very_frequently: 3,
    constantly: 4
  }

  enum :intensity, {
    mild: 0,
    moderate: 1,
    severe: 2
  }

  enum :category, {
    attention_seeking: 0,
    safety_concerns: 1,
    hyperactivity: 2,
    making_noises: 3,
    elopement: 4,
    flopping: 5,
    difficulty_with_transitions: 6,
    obsessive: 7,
    inappropriate: 8
  }

  # ABC Fields
  validates :behavior_name, presence: true
  validates :behavior_definition, presence: true
  validates :frequency, presence: true
  validates :intensity, presence: true
  validates :category, presence: true
  validates :antecedent, presence: true
  validates :consequence, presence: true
  validates :occurred_at, presence: true
  validates :location, presence: true

  # Scopes
  scope :for_student, ->(student_id) { where(student_id: student_id) }
  scope :for_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_frequency, ->(frequency) { where(frequency: frequency) }
  scope :by_intensity, ->(intensity) { where(intensity: intensity) }

  # Auto-populate behavior definition from dropdown options
  def set_behavior_definition
    return if behavior_definition.present?
    self.behavior_definition = BehaviorIncident.default_behavior_definitions[behavior_name] || behavior_name
  end

  # Class methods for dropdown options (returns array of strings for frontend)
  def self.frequency_options
    frequencies.keys.map(&:to_s)
  end

  def self.intensity_options
    intensities.keys.map(&:to_s)
  end

  def self.category_options
    categories.keys.map(&:to_s)
  end

  def self.default_behavior_definitions
    {
      "Elopement" => "Running or wandering away from supervision (moving away at least 5 feet)",
      "Unable to remain seated" => "Repeatedly standing up or leaning in seated position within a designated time frame during structured activities",
      "Biting others" => "Placing teeth on another person's hand and/or abdomen and applying pressure, resulting in visible marks or not",
      "Flopping" => "Throwing self on the floor suddenly",
      "Screaming" => "Producing a loud high-pitched sound that can be heard across the room"
    }
  end
end
