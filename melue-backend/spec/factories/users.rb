# spec/factories/users.rb
FactoryBot.define do
  factory :user do

    sequence(:email) { |n| "user#{n}@melue.foundation" }
    password_hash    { BCrypt::Password.create("Password123!") }
    status           { 2 }
    role             { :therapist }

    # rodauth uses password directly - no password_confirmation
    # If rodauth uses a different field name, try these:
    # password_hash { BCrypt::Password.create('password123') }
    # Or just create the user without password in tests

    trait :system_admin do
      role { :system_admin }
    end

    trait :institutional_admin do
      role { :institutional_admin }
    end

    trait :therapist do
      role { :therapist }
    end

    trait :clinical_staff do
      role { :clinical_staff }
    end
  end
end