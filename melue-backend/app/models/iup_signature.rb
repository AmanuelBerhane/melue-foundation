# frozen_string_literal: true

class IupSignature < ApplicationRecord
  belongs_to :iup
  belongs_to :signer_user, class_name: "User", foreign_key: :signer_user_id

  enum :signer_role, { program_director: "program_director", guardian: "guardian" }, prefix: true

  validates :signer_role, presence: true, uniqueness: { scope: :iup_id }
  validates :signed_at, presence: true

  def signer_name
    signer_user&.email || "Unknown"
  end
end
