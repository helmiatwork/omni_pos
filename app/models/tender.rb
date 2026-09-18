class Tender < ApplicationRecord
  METHODS = %w[wallet cash qris].freeze
  STATUSES = %w[pending captured reversed].freeze

  belongs_to :order

  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true

  def captured?
    status == 'captured'
  end

  def amount_money
    Money.new(amount_cents, 'IDR')
  end
end
