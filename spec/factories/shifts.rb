FactoryBot.define do
  factory :shift do
    device_id { SecureRandom.uuid }
    association :cashier, factory: :staff
    opening_cash { 200_000 }
    opened_at { Time.current }
  end
end
