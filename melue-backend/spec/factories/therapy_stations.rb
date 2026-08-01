# frozen_string_literal: true

FactoryBot.define do
  factory :therapy_station do
    name { "Station #{Faker::Alphanumeric.unique.alphanumeric(number: 4).upcase}" }
  end
end
