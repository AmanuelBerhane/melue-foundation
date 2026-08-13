# frozen_string_literal: true

FactoryBot.define do
  factory :student do
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 4, max_age: 12) }
    program_type  { "regular" }
    therapy_group { "basic" }
    status        { "active_therapy" }

    trait :registered do
      status { "registered" }
    end

    trait :basic_therapy_young do
      date_of_birth { Faker::Date.birthday(min_age: 3, max_age: 12) }
      therapy_group { "basic" }
    end

    trait :functional_living do
      date_of_birth { Faker::Date.birthday(min_age: 13, max_age: 19) }
      therapy_group { "functional_living" }
    end

    trait :with_guardian do
      guardian_name  { Faker::Name.name }
      guardian_phone { Faker::PhoneNumber.phone_number }
    end

    trait :with_headshot do
      after(:build) do |student|
        student.headshot.attach(
          io: StringIO.new("fake-image-data"),
          filename: "headshot.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
