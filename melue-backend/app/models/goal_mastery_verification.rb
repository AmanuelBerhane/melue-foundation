class GoalMasteryVerification < ApplicationRecord
  belongs_to :goal_mastery_check
  belongs_to :verifying_teacher, class_name: "StaffMember", foreign_key: "verifying_teacher_id"

  validates :outcome, presence: true, inclusion: { in: %w[success fail] }
  validates :prompt_used, presence: true, if: -> { outcome == "fail" }
end
