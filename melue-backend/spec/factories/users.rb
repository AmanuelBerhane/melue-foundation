# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@melue.foundation" }
    password_hash    { BCrypt::Password.create("Password123!") }
    status           { 2 } # verified
  end
end
