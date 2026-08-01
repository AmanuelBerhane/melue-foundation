# frozen_string_literal: true

FactoryBot.define do
  factory :staff_member do
    association :user
    full_name   { Faker::Name.name }
    staff_number { Faker::Alphanumeric.unique.alphanumeric(number: 6).upcase }
  end
end
