# frozen_string_literal: true

class PromptLevel < ApplicationRecord
  include Discard::Model
  include Auditable

  has_many :trials, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: true
  validates :color, presence: true, format: { with: /\A#?[0-9A-Fa-f]{6}\z/, message: "must be a valid hex code" }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true).order(:display_order) }
end
