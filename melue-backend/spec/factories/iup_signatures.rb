# frozen_string_literal: true

FactoryBot.define do
  factory :iup_signature do
    association :iup
    association :signer_user, factory: :user
    signer_role { "program_director" }
    signed_at { Time.current }
    signature_evidence { { timestamp: Time.current.iso8601 }.to_json }

    trait :guardian do
      signer_role { "guardian" }
    end

    trait :program_director do
      signer_role { "program_director" }
    end
  end
end
