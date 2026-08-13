# frozen_string_literal: true

FactoryBot.define do
  factory :goal_domain do
    sequence(:name)          { |n| "Domain #{n}" }
    sequence(:display_order) { |n| n }
    is_active { true }

    trait :active do
      is_active { true }
    end

    trait :inactive do
      is_active { false }
    end

    trait :with_goals do
      after(:create) do |domain|
        create_list(:goal, 2, goal_domain: domain)
      end
    end
  end
end
