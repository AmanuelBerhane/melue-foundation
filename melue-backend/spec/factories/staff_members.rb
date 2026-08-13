# frozen_string_literal: true

FactoryBot.define do
  factory :staff_member do
    association :user
    full_name   { Faker::Name.name }
    staff_number { Faker::Alphanumeric.unique.alphanumeric(number: 6).upcase }
    role { "teacher" }

    trait :therapy_coordinator do
      role { "therapy_coordinator" }
    end

    trait :program_director do
      role { "program_director" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
