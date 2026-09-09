# spec/factories/behavior_incidents.rb
FactoryBot.define do
  factory :behavior_incident do
    student
    staff_member
    behavior_name { 'Elopement' }
    behavior_definition { 'Running away from supervision' }
    frequency { :frequently }
    intensity { :moderate }
    category { :safety_concerns }
    antecedent { 'Transition to new activity' }
    consequence { 'Redirected back to activity' }
    location { 'Classroom' }
    occurred_at { Time.current }
    additional_notes { Faker::Lorem.sentence }
  end
end
