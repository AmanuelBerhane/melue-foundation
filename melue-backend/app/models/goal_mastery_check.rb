class GoalMasteryCheck < ApplicationRecord
  belongs_to :student_goal
  belongs_to :initiating_teacher, class_name: "StaffMember", foreign_key: "initiating_teacher_id"
  belongs_to :approving_director, class_name: "StaffMember", foreign_key: "approving_director_id", optional: true

  has_many :goal_mastery_verifications, dependent: :destroy

  enum :status, {
    pending_verifications: "pending_verifications",
    pending_approval: "pending_approval",
    approved: "approved",
    rejected: "rejected"
  }, prefix: true

  validates :status, presence: true
end
