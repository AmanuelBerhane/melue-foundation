# app/models/notification.rb
class Notification < ApplicationRecord
  self.inheritance_column = nil # 'type' column is a plain attribute, not STI

  belongs_to :recipient, class_name: "User", foreign_key: :recipient_user_id

  TYPES = %w[
    draft_reminder
    mastery_approval
    session_submission
    parent_communication
  ].freeze

  validates :type, inclusion: { in: TYPES }
  validates :payload_reference, presence: true
  validate :payload_reference_is_valid_json

  scope :unread, -> { where(read_at: nil) }
  scope :read,   -> { where.not(read_at: nil) }
  scope :for_recipient, ->(user_id) { where(recipient_user_id: user_id) }

  def read? = read_at.present?

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def payload
    @payload ||= JSON.parse(payload_reference)
  end

  private

  def payload_reference_is_valid_json
    JSON.parse(payload_reference)
  rescue JSON::ParserError, TypeError
    errors.add(:payload_reference, "must be valid JSON")
  end
end
