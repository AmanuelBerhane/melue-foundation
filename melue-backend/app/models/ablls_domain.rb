# frozen_string_literal: true

# Represents an ABLLS skill domain (e.g., "Visual Performance", "Cooperation").
#
# Domains group skill items and maintain a display order matching the physical
# ABLLS form. They are configurable through the Form Builder (SCR-ADMIN-001).
class AbllsDomain < ApplicationRecord
  include Discard::Model

  has_many :ablls_skill_items, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(:position) }
end
