class Order < ApplicationRecord
  VERTICALS = %w[grocery food carwash].freeze
  STATUSES = %w[created tendering paid fulfilling fulfilled voided refunded].freeze

  has_many :order_lines, dependent: :destroy
  has_many :tenders, dependent: :restrict_with_error

  validates :station_ref, presence: true
  validates :vertical, presence: true, inclusion: { in: VERTICALS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  def total_money
    Money.new(total_cents, 'IDR')
  end

  def paid?
    status == 'paid' || status == 'fulfilling' || status == 'fulfilled'
  end

  def recalculate_total!
    update!(total_cents: order_lines.sum(:total_cents))
  end

  def captured_tenders_total_cents
    tenders.where(status: 'captured').sum(:amount_cents)
  end

  def remaining_cents
    [total_cents - captured_tenders_total_cents, 0].max
  end
end
