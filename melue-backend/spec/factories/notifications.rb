# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    recipient_user_id { create(:user).id }
    type              { Notification::TYPES.sample }
    payload_reference { { summary: Faker::Lorem.sentence }.to_json }
    read_at           { nil }
  end
end
