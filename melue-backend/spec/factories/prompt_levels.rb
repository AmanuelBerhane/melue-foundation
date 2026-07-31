# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_level do
    sequence(:label)         { |n| "P#{n}" }
    sequence(:display_order) { |n| n }
    color     { "#22C55E" }
    is_active { true }
  end
end
