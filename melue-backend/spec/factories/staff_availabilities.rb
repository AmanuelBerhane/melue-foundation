# frozen_string_literal: true

FactoryBot.define do
  factory :staff_availability do
    association :staff_member
    session_block_definition { nil }
    unavailable_date { Date.current }
    reason { "Medical appointment" }

    trait :with_block do
      association :session_block_definition
    end
  end
end
