# frozen_string_literal: true

FactoryBot.define do
  factory :goal_domain do
    sequence(:name)          { |n| "Domain #{n}" }
    sequence(:display_order) { |n| n }
    is_active { true }
  end
end
