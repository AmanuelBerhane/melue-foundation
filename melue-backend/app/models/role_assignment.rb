# frozen_string_literal: true

class RoleAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :role

  # A role can only be actively held once per user. Revoking an assignment
  # frees up the role for re-assignment (matches the partial unique DB index).
  validates :role_id, uniqueness: { scope: :user_id, conditions: -> { where(revoked_at: nil) }, message: "is already actively assigned to this user" }

  scope :active, -> { where(revoked_at: nil) }

  # Returns whether this assignment is currently active.
  def active?
    revoked_at.nil?
  end

  # Revokes the assignment.
  def revoke!(at: Time.current)
    update!(revoked_at: at)
  end
end
