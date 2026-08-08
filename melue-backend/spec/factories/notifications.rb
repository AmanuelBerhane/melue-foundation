FactoryBot.define do
  factory :notification do
    recipient_user_id { "" }
    type { "" }
    payload_reference { "MyText" }
    read_at { "2026-08-05 21:41:59" }
  end
end
