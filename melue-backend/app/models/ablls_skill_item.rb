# frozen_string_literal: true

# Represents an individual ABLLS skill item (e.g., B1, B2, C1).
#
# Each item belongs to one domain and has a unique identifier matching the
# physical ABLLS form. Items maintain explicit ordering within their domain.
class AbllsSkillItem < ApplicationRecord
  include Discard::Model

  belongs_to :ablls_domain

  validates :identifier, presence: true, uniqueness: true
  validates :description, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(:position) }
end
