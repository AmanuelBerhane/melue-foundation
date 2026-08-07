# frozen_string_literal: true

FactoryBot.define do
  factory :preference_assessment do
    association :assessment_cycle
    status { "draft" }

    trait :submitted do
      status       { "submitted" }
      submitted_at { Time.current }
    end
  end
end
