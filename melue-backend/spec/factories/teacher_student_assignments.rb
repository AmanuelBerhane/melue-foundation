# frozen_string_literal: true

FactoryBot.define do
  factory :teacher_student_assignment do
    association :teacher, factory: :staff_member
    association :student
    association :session_block_definition
    association :therapy_station
    association :therapy_room
    scheduled_date { Date.current }
    status         { "scheduled" }
  end
end
