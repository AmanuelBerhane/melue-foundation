# frozen_string_literal: true

class SessionBlockDefinition < ApplicationRecord
  has_many :teacher_student_assignments, dependent: :restrict_with_error
  has_many :therapy_sessions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :round, presence: true
  validate :end_time_after_start_time

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:start_time) }

  # Returns seconds remaining until this block ends relative to now.
  # Returns 0 if the block has already ended.
  def seconds_remaining
    today_end = Time.current.change(
      hour: end_time.hour,
      min: end_time.min,
      sec: end_time.sec
    )
    remaining = today_end - Time.current
    [ remaining.to_i, 0 ].max
  end

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
