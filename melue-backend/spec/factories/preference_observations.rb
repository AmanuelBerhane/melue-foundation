# frozen_string_literal: true

FactoryBot.define do
  factory :preference_observation do
    association :preference_assessment
    association :preference_inventory_item
    context          { "sensory_time" }
    approached       { true }
    duration_seconds { 0 }
    frequency_count  { 0 }

    # A teacher-supplied item that is not in the global catalogue (FR-047f).
    trait :custom do
      preference_inventory_item     { nil }
      sequence(:custom_item_name)   { |n| "Custom item #{n}" }
      custom_item_category          { "Toys" }
    end
  end
end
