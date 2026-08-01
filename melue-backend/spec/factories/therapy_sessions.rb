# frozen_string_literal: true

FactoryBot.define do
  factory :therapy_session do
    association :teacher, factory: :staff_member
    association :session_block_definition
    association :therapy_station
    association :therapy_room
    status     { "in_progress" }
    started_at { Time.current }
  end
end
