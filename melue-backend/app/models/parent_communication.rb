# frozen_string_literal: true

# Staff ↔ guardian message about a child (SCR-PAR-004). `outbound` messages
# are sent by staff to the guardian; `inbound` messages come from the guardian.
class ParentCommunication < ApplicationRecord
  belongs_to :student
  belongs_to :guardian
  belongs_to :sender_user, class_name: "User"

  enum :direction, { inbound: "inbound", outbound: "outbound" }, prefix: true
  enum :kind, { progress_update: "progress_update", general: "general", alert: "alert" }, prefix: true

  validates :content, presence: true
  validates :direction, presence: true
  validates :kind, presence: true
  validates :sent_at, presence: true
  validate :guardian_linked_to_student

  scope :for_student, ->(student_id) { where(student_id: student_id) }
  scope :for_guardian, ->(guardian_id) { where(guardian_id: guardian_id) }
  scope :chronological, -> { order(sent_at: :asc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  # Idempotent: re-reading a message keeps the original read timestamp.
  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  private

  def guardian_linked_to_student
    return unless student_id && guardian_id
    return if StudentGuardian.exists?(student_id: student_id, guardian_id: guardian_id)

    errors.add(:guardian, "is not linked to this student")
  end
end
