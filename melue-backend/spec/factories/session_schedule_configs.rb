FactoryBot.define do
  factory :session_schedule_config do
    morning_start_time { "08:00" }
    morning_end_time { "12:00" }
    afternoon_start_time { "13:00" }
    afternoon_end_time { "17:00" }
    pre_therapy_duration_minutes { 15 }
    station_1_duration_minutes { 30 }
    station_2_duration_minutes { 30 }
    staff_to_student_capacity { 4 }
    draft_expiry_days { 7 }

    trait :extended_hours do
      morning_start_time { "07:00" }
      morning_end_time { "13:00" }
      afternoon_start_time { "14:00" }
      afternoon_end_time { "19:00" }
    end

    trait :high_capacity do
      staff_to_student_capacity { 8 }
    end

    trait :short_sessions do
      station_1_duration_minutes { 20 }
      station_2_duration_minutes { 20 }
    end
  end
end
