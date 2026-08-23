class FormSubmission < ApplicationRecord
  include Discard::Model

  belongs_to :form_configuration
  belongs_to :submittable, polymorphic: true

  enum :status, { draft: "draft", submitted: "submitted", finalized: "finalized" }, prefix: true

  validates :status, presence: true
  validates :values, exclusion: { in: [nil], message: "can't be nil" }
  validates :submittable_id, uniqueness: { scope: :submittable_type }

  def update_field(field_key, value)
    new_values = values.dup
    new_values[field_key] = value
    update!(values: new_values)
  end

  def get_field(field_key)
    values[field_key]
  end
end
