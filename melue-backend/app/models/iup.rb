# frozen_string_literal: true

class Iup < ApplicationRecord
  include Discard::Model

  belongs_to :student

  has_many :student_goals, dependent: :restrict_with_error

  enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true

  validates :status, presence: true
  validates :student, presence: true
  validate :only_one_active_iup_per_student, if: :status_active?

  scope :active, -> { where(status: "active") }

  private

  def only_one_active_iup_per_student
    existing = Iup.where(student_id: student_id, status: "active")
    existing = existing.where.not(id: id) if persisted?
    errors.add(:base, "student already has an active IUP") if existing.exists?
  end
end
