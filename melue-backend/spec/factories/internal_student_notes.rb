# frozen_string_literal: true

FactoryBot.define do
  factory :internal_student_note do
    association :student
    author      { association(:user) }
    content     { Faker::Lorem.sentence }
    recorded_at { Time.current }
  end
end
