# frozen_string_literal: true

class GoalDomain < ApplicationRecord
  include Auditable

  has_many :goals, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true).order(:display_order) }
end
