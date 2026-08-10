# frozen_string_literal: true

FactoryBot.define do
  factory :abc_dropdown_option do
    sequence(:label)         { |n| "Option #{n}" }
    sequence(:display_order) { |n| n }
    category  { :antecedent }
    is_active { true }
    is_other  { false }

    trait :antecedent do
      category { :antecedent }
    end

    trait :behavior do
      category { :behavior }
    end

    trait :consequence do
      category { :consequence }
    end

    trait :is_other do
      is_other { true }
      sequence(:label) { |n| "Other #{n}" }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
