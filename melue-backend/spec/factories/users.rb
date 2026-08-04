# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    # rodauth uses password directly - no password_confirmation
    password { 'password123' }

    # If rodauth uses a different field name, try these:
    # password_hash { BCrypt::Password.create('password123') }
    # Or just create the user without password in tests
  end
end
