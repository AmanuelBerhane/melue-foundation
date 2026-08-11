class AbcDropdownOption < ApplicationRecord
  include Auditable

  enum :category, { antecedent: 0, behavior: 1, consequence: 2 }

  validates :label, presence: true
  validates :category, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :label, uniqueness: { scope: :category, case_sensitive: false }
  validate :only_one_other_per_category, if: :is_other?

  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(cat) { where(category: cat).order(:display_order) }

  private

  def only_one_other_per_category
    existing = self.class.where(category: category, is_other: true)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:is_other, "only one 'Other' option allowed per category") if existing.exists?
  end
end
