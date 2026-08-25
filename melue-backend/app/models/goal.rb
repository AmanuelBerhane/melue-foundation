# frozen_string_literal: true

class Goal < ApplicationRecord
  include Discard::Model

  belongs_to :goal_domain

  has_many :student_goals, dependent: :restrict_with_error
  has_many :task_analysis_step_templates,
         -> { order(:step_number) },
         dependent: :destroy,
         inverse_of: :goal

  enum :goal_type, { standard: "standard", task_analysis: "task_analysis" }, prefix: true

  validates :name, presence: true
  validates :goal_type, presence: true
  validates :goal_domain, presence: true

  scope :active, -> { where(is_active: true) }
  scope :standard, -> { where(goal_type: "standard") }
  scope :task_analysis, -> { where(goal_type: "task_analysis") }
end
