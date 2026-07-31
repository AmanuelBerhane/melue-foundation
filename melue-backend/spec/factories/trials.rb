# frozen_string_literal: true

FactoryBot.define do
  factory :trial do
    association :prompt_level
    prompt_label_snapshot { "FP" }
    outcome               { "correct" }
    client_event_id       { SecureRandom.uuid }
    logged_at             { Time.current }

    # All three must be consistent: session, participant (belongs to session),
    # and goal (belongs to participant's student).
    therapy_session     { association(:therapy_session) }
    session_participant { association(:session_participant, therapy_session: therapy_session) }
    student_goal        { association(:student_goal, student: session_participant.student, iup: association(:iup, student: session_participant.student)) }
  end
end
