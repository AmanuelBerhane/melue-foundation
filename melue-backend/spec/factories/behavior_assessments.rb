# frozen_string_literal: true

FactoryBot.define do
  factory :behavior_assessment do
    association :assessment_cycle
    status { "draft" }

    trait :in_progress do
      status { "in_progress" }
      started_at { Time.current }
    end

    trait :submitted do
      status { "submitted" }
      started_at { Time.current }
      submitted_at { Time.current }
    end
  end
end
