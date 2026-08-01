# frozen_string_literal: true

FactoryBot.define do
  factory :therapy_room do
    association :therapy_station
    name { "Room #{Faker::Alphanumeric.unique.alphanumeric(number: 3).upcase}" }
  end
end
