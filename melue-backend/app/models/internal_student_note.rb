# frozen_string_literal: true

# FR-135: Internal notes about students added by Directors/Oversight staff.
# Must never be returned by parent-facing or teacher-facing API endpoints.
class InternalStudentNote < ApplicationRecord
  belongs_to :student
  belongs_to :author, class_name: "User"

  validates :content, presence: true
  validates :recorded_at, presence: true

  scope :recent, -> { order(recorded_at: :desc) }

  # Convenience method for author full name
  def author_name
    author&.staff_member&.full_name || author&.email || "Unknown Author"
  end

  def author_role
    author&.primary_role&.name || author&.role&.to_s&.titleize || "Staff"
  end
end
