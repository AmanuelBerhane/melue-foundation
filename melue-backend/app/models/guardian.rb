# frozen_string_literal: true

class Guardian < ApplicationRecord
  belongs_to :user, optional: true

  has_many :student_guardians, dependent: :restrict_with_error
  has_many :students, through: :student_guardians

  validates :full_name, presence: true

  # A guardian may exist without a linked portal account (invitation is optional).
  def has_portal_access?
    user.present? && user.role_assignments.active.exists?(role: Role.find_by(name: Role::Names::PARENT))
  end
end
