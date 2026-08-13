class StudentDocument < ApplicationRecord
  belongs_to :student

  enum :document_type, {
    birth_certificate: "birth_certificate",
    diagnosis_paper: "diagnosis_paper",
    agreement: "agreement",
    other: "other"
  }

  has_one_attached :file

  validates :document_type, presence: true
  validates :file, presence: true

  # ActiveStorage validation
  validate :file_format_and_size

  scope :for_enrollment, -> { where(document_type: [ "birth_certificate", "diagnosis_paper", "agreement" ]) }

  private

  def file_format_and_size
    return unless file.attached?

    unless file.content_type.in?(%w[application/pdf image/jpeg image/png image/webp])
      errors.add(:file, "must be PDF, JPEG, PNG, or WEBP")
    end

    if file.byte_size > 10.megabytes
      errors.add(:file, "size must be less than 10MB")
    end
  end
end
