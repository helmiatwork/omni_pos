class OrderLine < ApplicationRecord
  belongs_to :order

  validates :name, presence: true
  validates :qty, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :compute_total_cents, if: -> { total_cents.to_i.zero? && unit_price_cents.to_i.positive? }

  def unit_price_money
    Money.new(unit_price_cents, 'IDR')
  end

  def total_money
    Money.new(total_cents, 'IDR')
  end

  private

  def compute_total_cents
    self.total_cents = (qty.to_d * unit_price_cents).round
  end
end
