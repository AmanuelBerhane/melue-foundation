# frozen_string_literal: true

FactoryBot.define do
  factory :ablls_domain do
    sequence(:code) { |n| ('A'..'Z').to_a[n % 26] + (n > 25 ? (n / 26).to_s : "") }
    sequence(:name) { |n| "ABLLS Domain #{n}" }
    sequence(:position) { |n| n }
    is_active { true }

    trait :inactive do
      is_active { false }
    end
  end
end
