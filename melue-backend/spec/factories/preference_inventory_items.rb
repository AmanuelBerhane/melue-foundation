# frozen_string_literal: true

FactoryBot.define do
  factory :preference_inventory_item do
    sequence(:name) { |n| "Inventory item #{n}" }
    category        { "Toys" }
    is_active       { true }

    trait :inactive do
      is_active { false }
    end
  end
end
