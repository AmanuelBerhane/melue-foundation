FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password_hash { RodauthApp.rodauth.allocate.password_hash("password123") }
    status { :verified }
  end
end
