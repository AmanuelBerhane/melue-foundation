class TaskAnalysisStepTemplate < ApplicationRecord
  belongs_to :goal

  has_many :student_goal_steps, dependent: :nullify

  validates :step_number, presence: true,
                          uniqueness: { scope: :goal_id }
  validates :name, presence: true

  scope :ordered, -> { order(:step_number) }
end
