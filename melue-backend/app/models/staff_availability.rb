# frozen_string_literal: true

class StaffAvailability < ApplicationRecord
  belongs_to :staff_member
  belongs_to :session_block_definition, optional: true

  validates :unavailable_date, presence: true
  validates :staff_member_id, presence: true

  validate :validate_uniqueness_on_date_and_block

  scope :for_date, ->(date) { where(unavailable_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(unavailable_date: start_date..end_date) }
  scope :for_teacher, ->(teacher_id) { where(staff_member_id: teacher_id) }
  scope :for_block, ->(block_id) { where(session_block_definition_id: block_id) }
  scope :full_day, -> { where(session_block_definition_id: nil) }
  scope :block_specific, -> { where.not(session_block_definition_id: nil) }

  scope :active_on, ->(date, block_id = nil) {
    if block_id.present?
      where(unavailable_date: date).where(session_block_definition_id: [ nil, block_id ])
    else
      where(unavailable_date: date)
    end
  }

  def full_day?
    session_block_definition_id.nil?
  end

  private

  def validate_uniqueness_on_date_and_block
    return unless staff_member_id && unavailable_date

    if full_day?
      existing = StaffAvailability.where(staff_member_id: staff_member_id, unavailable_date: unavailable_date)
      existing = existing.where.not(id: id) if persisted?
      if existing.where(session_block_definition_id: nil).exists?
        errors.add(:base, "Staff member is already marked unavailable for the full day on this date")
      end
    else
      existing = StaffAvailability.where(
        staff_member_id: staff_member_id,
        unavailable_date: unavailable_date,
        session_block_definition_id: session_block_definition_id
      )
      existing = existing.where.not(id: id) if persisted?
      if existing.exists?
        errors.add(:base, "Staff member is already marked unavailable for this session block on this date")
      end
    end
  end
end
