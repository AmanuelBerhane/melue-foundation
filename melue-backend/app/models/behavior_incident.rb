# app/models/behavior_incident.rb
class BehaviorIncident < ApplicationRecord
  # Associations
  belongs_to :student
  belongs_to :staff_member, optional: true
  belongs_to :teacher, class_name: "StaffMember", foreign_key: :staff_member_id, optional: true
  belongs_to :therapy_session, optional: true
  belongs_to :student_goal, optional: true
  has_one :goal, through: :student_goal

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

  # Callbacks
  after_initialize :set_defaults, if: :new_record?
  before_validation :set_behavior_definition, on: :create

  # ABC Fields Validations
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
  scope :for_therapy_session, ->(session_id) { where(therapy_session_id: session_id) }
  scope :for_staff_member, ->(staff_id) { where(staff_member_id: staff_id) }
  scope :for_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_frequency, ->(frequency) { where(frequency: frequency) }
  scope :by_intensity, ->(intensity) { where(intensity: intensity) }
  scope :recent, -> { order(occurred_at: :desc) }

  # Auto-populate defaults on initialize
  def set_defaults
    self.occurred_at ||= Time.current
    if behavior_name.present? && (!category_came_from_user? || category.nil?) && BehaviorIncident.default_behavior_categories[behavior_name].present?
      self.category = BehaviorIncident.default_behavior_categories[behavior_name]
    end
    set_behavior_definition
  end

  # Auto-populate behavior definition from dropdown options
  def set_behavior_definition
    return if behavior_definition.present?

    definition = BehaviorIncident.default_behavior_definitions[behavior_name]

    if definition.blank? && defined?(AbcDropdownOption)
      opt = AbcDropdownOption.active.find_by("LOWER(label) = ?", behavior_name.to_s.strip.downcase)
      definition = opt&.label
    end

    self.behavior_definition = definition.presence || behavior_name
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

  def self.default_behavior_categories
    {
      "Elopement" => :safety_concerns,
      "Unable to remain seated" => :hyperactivity,
      "Biting others" => :safety_concerns,
      "Flopping" => :flopping,
      "Screaming" => :making_noises
    }
  end

  # Comprehensive modal options for SCR-003
  def self.modal_options
    behaviors = default_behavior_definitions.map do |name, definition|
      {
        name: name,
        definition: definition,
        default_category: default_behavior_categories[name]&.to_s
      }
    end

    if defined?(AbcDropdownOption)
      custom_options = AbcDropdownOption.where(category: :behavior, is_active: true).order(:display_order)
      custom_options.each do |opt|
        unless behaviors.any? { |b| b[:name].casecmp(opt.label).zero? }
          behaviors << {
            name: opt.label,
            definition: opt.label,
            default_category: nil
          }
        end
      end
    end

    antecedent_options = if defined?(AbcDropdownOption)
      AbcDropdownOption.where(category: :antecedent, is_active: true).order(:display_order).pluck(:label)
    else
      []
    end
    antecedents = antecedent_options.presence || [
      "Transition between activities",
      "Demand placed / Instruction given",
      "Attention removed / redirected",
      "Denied access to item/activity",
      "Sensory overload / Loud noise"
    ]

    consequence_options = if defined?(AbcDropdownOption)
      AbcDropdownOption.where(category: :consequence, is_active: true).order(:display_order).pluck(:label)
    else
      []
    end
    consequences = consequence_options.presence || [
      "Verbal redirection / Prompting",
      "Temporary removal of task",
      "Provided sensory break",
      "Planned ignoring",
      "Differential reinforcement"
    ]

    {
      behaviors: behaviors,
      frequencies: [
        { value: "rarely", label: "Rarely", meaning: "Occurs once a week or less" },
        { value: "occasionally", label: "Occasionally", meaning: "Occurs a few times a week" },
        { value: "frequently", label: "Frequently", meaning: "Occurs daily" },
        { value: "very_frequently", label: "Very Frequently", meaning: "Occurs multiple times per day" },
        { value: "constantly", label: "Constantly", meaning: "Occurs every session" }
      ],
      intensities: [
        { value: "mild", label: "Mild" },
        { value: "moderate", label: "Moderate" },
        { value: "severe", label: "Severe" }
      ],
      categories: [
        { value: "attention_seeking", label: "Attention-seeking", description: "Behavior performed to gain attention" },
        { value: "safety_concerns", label: "Safety concerns", description: "Behavior that poses a safety risk" },
        { value: "hyperactivity", label: "Not sitting still / Hyperactivity", description: "Unable to remain seated, constant movement" },
        { value: "making_noises", label: "Making noises, interrupting conversation", description: "Vocal or auditory disruptions" },
        { value: "elopement", label: "Elopement", description: "Running or wandering away from supervision" },
        { value: "flopping", label: "Flopping", description: "Throwing self on the floor suddenly" },
        { value: "difficulty_with_transitions", label: "Difficulty with transitions", description: "Crying, refusing, or resisting changes in activity" },
        { value: "obsessive", label: "Obsessive", description: "Fixating on one topic/object, difficulty shifting focus" },
        { value: "inappropriate", label: "Inappropriate", description: "Humming, shouting, or making noises at quiet times" }
      ],
      antecedents: antecedents,
      consequences: consequences,
      locations: [
        "Therapy room",
        "Snack place",
        "Playground",
        "Restroom",
        "Hallway",
        "Sensory room"
      ]
    }
  end
end
