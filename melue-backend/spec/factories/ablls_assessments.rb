# frozen_string_literal: true

FactoryBot.define do
  factory :ablls_assessment do
    association :assessment_cycle
    association :staff_member
    status { "draft" }
    started_at { Time.current }

    trait :in_progress do
      status { "in_progress" }
    end

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
    end
  end
end
