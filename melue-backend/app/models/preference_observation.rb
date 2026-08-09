# frozen_string_literal: true

# A single item observed in a single context (FR-047b, FR-047e, FR-047f).
#
# duration_seconds and frequency_count are the accumulated totals from the
# teacher's timer and counter. combined_score, rank and tier are derived — they
# are written only by PreferenceAssessments::RankObservationsService.
class PreferenceObservation < ApplicationRecord
  belongs_to :preference_assessment

  # Optional: a NULL item means a custom item the teacher typed in (FR-047f).
  # Custom items live on the observation and are never written back to the
  # global catalogue.
  belongs_to :preference_inventory_item, optional: true

  enum :context, {
    sensory_time: "sensory_time",
    circle_time: "circle_time",
    play_time: "play_time"
  }, prefix: true

  enum :tier, { highest: "highest", moderate: "moderate", low: "low" }, prefix: true

  validates :context, presence: true
  validates :duration_seconds,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :frequency_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :exactly_one_item_source
  validate :custom_category_requires_custom_item

  scope :ranked, lambda {
    order(Arel.sql('"preference_observations"."rank" ASC NULLS LAST')).order(:id)
  }

  # Name and category resolve through the catalogue when present, and fall back
  # to the custom values the teacher supplied.
  def item_name
    preference_inventory_item&.name || custom_item_name
  end

  def item_category
    preference_inventory_item&.category || custom_item_category
  end

  def custom_item?
    !catalogue_item?
  end

  # Only items the student actually engaged with can be ranked into a
  # preference tier; everything else is Low Preferred by definition.
  def engaged?
    duration_seconds.to_i.positive? || frequency_count.to_i.positive?
  end

  private

  # Checks the association rather than the FK, so an unsaved item assigned in
  # memory still counts as a catalogue selection.
  def catalogue_item?
    preference_inventory_item_id.present? || preference_inventory_item.present?
  end

  def exactly_one_item_source
    if catalogue_item? && custom_item_name.present?
      errors.add(:custom_item_name,
                 "cannot be set when an inventory item is selected")
    elsif !catalogue_item? && custom_item_name.blank?
      errors.add(:base, "an inventory item or a custom item name is required")
    end
  end

  def custom_category_requires_custom_item
    return if custom_item_category.blank?
    return unless catalogue_item?

    errors.add(:custom_item_category,
               "cannot be set when an inventory item is selected")
  end
end
