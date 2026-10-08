# frozen_string_literal: true

class GuardianSerializer < ApplicationSerializer
  private

  def serialize(guardian)
    { id: guardian.id, full_name: guardian.full_name, phone: guardian.phone }
  end
end
