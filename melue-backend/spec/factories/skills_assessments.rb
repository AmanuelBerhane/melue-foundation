# frozen_string_literal: true

FactoryBot.define do
  factory :skills_assessment do
    association :assessment_cycle
    status { "draft" }
    progress_percent { 0 }

    trait :in_progress do
      status { "in_progress" }
      progress_percent { 45 }
      started_at { Time.current }
    end

    trait :submitted do
      status { "submitted" }
      progress_percent { 100 }
      started_at { Time.current }
      submitted_at { Time.current }
    end
  end
end
