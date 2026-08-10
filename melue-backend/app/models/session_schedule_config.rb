class SessionScheduleConfig < ApplicationRecord
  include Auditable

  def as_json(options = {})
    super(options).tap do |hash|
      hash["morning_start_time"] = morning_start_time&.strftime("%H:%M")
      hash["morning_end_time"] = morning_end_time&.strftime("%H:%M")
      hash["afternoon_start_time"] = afternoon_start_time&.strftime("%H:%M")
      hash["afternoon_end_time"] = afternoon_end_time&.strftime("%H:%M")
    end
  end

  validates :morning_start_time, presence: true
  validates :morning_end_time, presence: true
  validates :afternoon_start_time, presence: true
  validates :afternoon_end_time, presence: true
  validates :pre_therapy_duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :station_1_duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :station_2_duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :staff_to_student_capacity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :draft_expiry_days, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :morning_end_after_start
  validate :afternoon_end_after_start

  def self.instance
    first_or_create!(
      morning_start_time: "08:00",
      morning_end_time: "12:00",
      afternoon_start_time: "13:00",
      afternoon_end_time: "17:00",
      pre_therapy_duration_minutes: 15,
      station_1_duration_minutes: 30,
      station_2_duration_minutes: 30,
      staff_to_student_capacity: 4,
      draft_expiry_days: 7
    )
  end

  private

  def morning_end_after_start
    return unless morning_start_time && morning_end_time
    errors.add(:morning_end_time, "must be after morning start time") if morning_end_time <= morning_start_time
  end

  def afternoon_end_after_start
    return unless afternoon_start_time && afternoon_end_time
    errors.add(:afternoon_end_time, "must be after afternoon start time") if afternoon_end_time <= afternoon_start_time
  end
end
