# frozen_string_literal: true

FactoryBot.define do
  factory :ablls_response do
    association :ablls_assessment
    association :ablls_skill_item
    score { nil }
    note { nil }

    trait :score_0 do
      score { "0" }
    end

    trait :score_1 do
      score { "1" }
    end

    trait :score_2 do
      score { "2" }
    end

    trait :not_applicable do
      score { "not_applicable" }
    end

    trait :with_note do
      note { "Teacher observation note" }
    end
  end
end
