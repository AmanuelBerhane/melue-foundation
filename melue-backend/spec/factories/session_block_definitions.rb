# frozen_string_literal: true

FactoryBot.define do
  factory :session_block_definition do
    sequence(:name) { |n| "Block #{n}" }
    start_time { "08:00" }
    end_time   { "09:30" }
    round      { "morning" }
    is_active  { true }

    trait :morning do
      start_time { "08:00" }
      end_time   { "09:30" }
      round      { "morning" }
    end

    trait :afternoon do
      start_time { "13:00" }
      end_time   { "14:30" }
      round      { "afternoon" }
    end

    trait :custom_times do
      transient do
        block_start { "10:00" }
        block_end   { "11:30" }
      end
      start_time { block_start }
      end_time   { block_end }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
