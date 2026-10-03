# frozen_string_literal: true

FactoryBot.define do
  factory :guardian do
    association :user
    full_name { Faker::Name.name }
    phone     { Faker::PhoneNumber.phone_number }
  end

  factory :student_guardian do
    association :student
    association :guardian
    relationship       { "mother" }
    is_primary_contact { true }
  end

  factory :home_observation do
    association :student
    guardian     { association(:guardian) }
    content      { Faker::Lorem.sentence }
    observed_on  { Date.current }
    submitted_at { Time.current }
  end

  factory :parent_communication do
    association :student
    guardian    { association(:guardian) }
    sender_user { association(:user) }
    direction   { "outbound" }
    kind        { "general" }
    content     { Faker::Lorem.sentence }
    sent_at     { Time.current }
  end
end
