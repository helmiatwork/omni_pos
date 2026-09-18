class PosAuditEvent < ApplicationRecord
  EVENT_NAMES = %w[void refund price_override no_sale_open safe_drop shift_open shift_close].freeze

  validates :actor_id, presence: true
  validates :event_name, presence: true

  def readonly?
    persisted?
  end
end
