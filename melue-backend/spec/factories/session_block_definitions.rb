# frozen_string_literal: true

FactoryBot.define do
  factory :session_block_definition do
    sequence(:name) { |n| "Block #{n}" }
    start_time { "08:00" }
    end_time   { "09:30" }
    round      { "morning" }
    is_active  { true }
  end
end
