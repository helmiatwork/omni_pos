FactoryBot.define do
  factory :order do
    station_ref { "POS-01" }
    vertical { "grocery" }
    status { "created" }
    total_cents { 50_000 }
    metadata { {} }
  end

  factory :order_line do
    association :order
    name { "Apel Malang" }
    sku { "APL-01" }
    qty { 1.5 }
    unit { "kg" }
    unit_price_cents { 20_000 }
    total_cents { 30_000 }
    modifiers { {} }
  end
end
