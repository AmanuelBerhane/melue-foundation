class StudentGoalStep < ApplicationRecord
  belongs_to :student_goal
  belongs_to :task_analysis_step_template, optional: true

  has_many :trials, dependent: :nullify,
                    foreign_key: :student_goal_step_id,
                    inverse_of: :student_goal_step

  enum :status, {
    not_started: "not_started",
    in_progress: "in_progress",
    mastered: "mastered"
  }, default: :not_started, validate: true

  validates :step_number, presence: true,
                          uniqueness: { scope: :student_goal_id }
  validates :name, presence: true
  validates :independence_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :ordered, -> { order(:step_number) }
end
