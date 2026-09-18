FactoryBot.define do
  factory :tender do
    association :order
    add_attribute(:method) { "wallet" }
    amount_cents { 50_000 }
    status { "captured" }
    idempotency_key { SecureRandom.uuid }
    reference_id { "WAL-#{SecureRandom.hex(4).upcase}" }
    metadata { {} }
  end

  factory :pos_audit_event do
    actor_id { SecureRandom.uuid }
    event_name { "void" }
    payload { { reason: "Customer canceled order" } }
  end
end
