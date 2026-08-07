# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :user
    action        { "create" }
    resource_type { "GoalDomain" }
    resource_id   { "1" }
    change_data do
      {
        "name" => [ nil, "Example Domain" ]
      }
    end
    metadata { {} }
  end
end
