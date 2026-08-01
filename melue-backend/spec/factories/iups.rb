# frozen_string_literal: true

FactoryBot.define do
  factory :iup do
    association :student
    status { "active" }

    trait :draft do
      status { "draft" }
    end
  end
end
