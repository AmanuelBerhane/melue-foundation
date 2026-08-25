# frozen_string_literal: true

# The foundation's default preference item catalogue (SRS 3.3.4, FR-047a).
#
# Administrators curate this list via the Form Builder. Items are retired by
# flipping is_active rather than deleted, because inventory changes must never
# erase the observations that reference them.
class PreferenceInventoryItem < ApplicationRecord
  include Discard::Model

  has_many :preference_observations, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { scope: :category, case_sensitive: false }
  validates :category, presence: true

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:category, :name) }
end
