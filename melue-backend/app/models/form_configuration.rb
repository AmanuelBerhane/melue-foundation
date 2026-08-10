class FormConfiguration < ApplicationRecord
  include Auditable

  enum :form_type, { enrollment: 0, iup: 1, ablls: 2 }

  validates :form_name, presence: true
  validates :form_type, presence: true
  validates :field_schema, presence: true
  validate :field_schema_structure
  validate :unique_field_ids
  validate :supported_field_types

  before_validation :set_revision_date

  SUPPORTED_FIELD_TYPES = %w[text number date dropdown checkbox radio textarea file_upload].freeze

  private

  def set_revision_date
    self.revision_date ||= Date.current
  end

  def field_schema_structure
    return if field_schema.blank?
    errors.add(:field_schema, "must be a hash") unless field_schema.is_a?(Hash)
    errors.add(:field_schema, "must contain 'fields' array") unless field_schema["fields"].is_a?(Array)
  end

  def unique_field_ids
    return unless field_schema["fields"].is_a?(Array)
    ids = field_schema["fields"].map { |f| f["id"] }.compact
    errors.add(:field_schema, "contains duplicate field IDs") if ids.uniq.length != ids.length
  end

  def supported_field_types
    return unless field_schema["fields"].is_a?(Array)
    field_schema["fields"].each do |field|
      next if SUPPORTED_FIELD_TYPES.include?(field["type"])
      errors.add(:field_schema, "unsupported field type: #{field['type']}")
    end
  end
end
