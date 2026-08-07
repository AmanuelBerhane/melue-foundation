# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_level do
    sequence(:label)         { |n| "P#{n}" }
    sequence(:display_order) { |n| n }
    color     { "#22C55E" }
    is_active { true }

    trait :active do
      is_active { true }
    end

    trait :inactive do
      is_active { false }
    end

    trait :custom_color do
      transient do
        hex_color { "#FF5733" }
      end
      color { hex_color }
    end
  end
end
