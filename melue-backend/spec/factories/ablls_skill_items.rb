# frozen_string_literal: true

FactoryBot.define do
  factory :ablls_skill_item do
    association :ablls_domain
    sequence(:identifier) { |n| "#{ablls_domain&.code || 'X'}#{n}" }
    sequence(:description) { |n| "ABLLS skill item description #{n}" }
    sequence(:position) { |n| n }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
