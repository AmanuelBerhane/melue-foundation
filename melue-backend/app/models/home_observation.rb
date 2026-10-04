# frozen_string_literal: true

# Guardian-submitted update about a child's behaviour or progress at home
# (SCR-PAR-003). Read-only from the therapy side: a submission never alters
# a clinical record.
class HomeObservation < ApplicationRecord
  belongs_to :student
  belongs_to :guardian

  validates :content, presence: true
  validates :observed_on, presence: true
  validates :submitted_at, presence: true
  validate :guardian_linked_to_student

  scope :for_student, ->(student_id) { where(student_id: student_id) }
  scope :for_guardian, ->(guardian_id) { where(guardian_id: guardian_id) }
  scope :chronological, -> { order(observed_on: :desc, submitted_at: :desc) }

  private

  def guardian_linked_to_student
    return unless student_id && guardian_id
    return if StudentGuardian.exists?(student_id: student_id, guardian_id: guardian_id)

    errors.add(:guardian, "is not linked to this student")
  end
end
