FactoryBot.define do
  factory :drawer_event do
    association :shift
    event_type { "safe_drop" }
    amount { 50_000 }
    association :authorized_staff, factory: :staff
  end
end
