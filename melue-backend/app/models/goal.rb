# frozen_string_literal: true

class Goal < ApplicationRecord
  include Discard::Model

  belongs_to :goal_domain

  has_many :student_goals, dependent: :restrict_with_error
  has_many :task_analysis_step_templates,
         -> { order(:step_number) },
         dependent: :destroy,
         inverse_of: :goal

  accepts_nested_attributes_for :task_analysis_step_templates, allow_destroy: true

  enum :goal_type, { standard: "standard", task_analysis: "task_analysis" }, prefix: true

  validates :name, presence: true
  validates :goal_type, presence: true
  validates :goal_domain, presence: true
  validate :validate_task_analysis_steps, if: :goal_type_task_analysis?

  before_destroy :prevent_deletion_if_assigned_to_active_students, prepend: true
  before_discard :prevent_deletion_if_assigned_to_active_students

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :standard, -> { where(goal_type: "standard") }
  scope :task_analysis, -> { where(goal_type: "task_analysis") }
  scope :by_domain, ->(domain_id) { where(goal_domain_id: domain_id) if domain_id.present? }
  scope :search_text, ->(query) {
    if query.present?
      sanitized = "%#{sanitize_sql_like(query.to_s.downcase)}%"
      where("LOWER(goals.name) LIKE :q OR LOWER(goals.description) LIKE :q", q: sanitized)
    end
  }

  attr_writer :custom_usage_count

  # FR-078: The usage count for each goal, representing the number of students currently assigned to the goal
  def usage_count
    return @custom_usage_count if defined?(@custom_usage_count) && !@custom_usage_count.nil?

    active_student_assignments.select(:student_id).distinct.count
  end

  # Returns currently active student assignments (active/in_progress on active, non-exited students)
  def active_student_assignments
    student_goals
      .kept
      .where(status: %w[active in_progress])
      .joins(:student)
      .where(students: { discarded_at: nil })
      .where.not(students: { status: %w[withdrawn discharged archived] })
  end

  # FR-077: Check if goal is currently assigned to active students
  def assigned_to_active_students?
    active_student_assignments.exists?
  end

  # FR-076: Deactivate goal to prevent new assignments while preserving existing
  def deactivate!
    update!(is_active: false)
  end

  def activate!
    update!(is_active: true)
  end

  def applicable_to_therapy_group?(therapy_group)
    applicable_therapy_groups.empty? || applicable_therapy_groups.include?(therapy_group)
  end

  def self.for_therapy_group(therapy_group)
    where("? = ANY(applicable_therapy_groups) OR applicable_therapy_groups = '{}'", therapy_group)
  end

  private

  def prevent_deletion_if_assigned_to_active_students
    if assigned_to_active_students?
      errors.add(:base, "Cannot delete goal currently assigned to active students")
      throw(:abort)
    end
  end

  def validate_task_analysis_steps
    step_numbers = task_analysis_step_templates.reject(&:_destroy).map(&:step_number).compact
    if step_numbers.size != step_numbers.uniq.size
      errors.add(:base, "Step numbers must be unique within the goal")
    end
  end
end
