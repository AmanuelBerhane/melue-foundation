# frozen_string_literal: true

FactoryBot.define do
  factory :session_summary do
    association :therapy_session
    qualitative_notes { Faker::Lorem.paragraph }
    status { :draft }

    trait :submitted do
      status { :submitted }
      submitted_at { Time.current }
    end

    trait :reviewed do
      status { :reviewed }
      submitted_at { Time.current - 1.hour }
      reviewed_at { Time.current }
      association :reviewed_by_user, factory: :user, role: :clinical_staff
    end
  end
end
