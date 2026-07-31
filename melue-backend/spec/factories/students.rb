# frozen_string_literal: true

FactoryBot.define do
  factory :student do
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 4, max_age: 12) }
    program_type  { "regular" }
    therapy_group { "basic" }
    status        { "active_therapy" }
  end
end
