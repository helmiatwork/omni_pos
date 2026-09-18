FactoryBot.define do
  factory :staff do
    name { "Budi Kasir" }
    role { "cashier" }
    pin { "123456" }
    active { true }
  end
end
