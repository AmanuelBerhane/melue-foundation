# frozen_string_literal: true

FactoryBot.define do
  factory :goal do
    association :goal_domain
    sequence(:name) { |n| "Goal #{n}" }
    goal_type { "standard" }
    is_active { true }

    trait :task_analysis do
      goal_type { "task_analysis" }
    end
  end
end
