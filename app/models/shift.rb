class Shift < ApplicationRecord
  belongs_to :cashier, class_name: 'Staff'
  has_many :drawer_events, dependent: :restrict_with_error

  validates :device_id, presence: true
  validates :opening_cash, numericality: { greater_than_or_equal_to: 0 }

  scope :open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }

  def opened?
    closed_at.nil?
  end

  def closed?
    closed_at.present?
  end

  def opening_money
    Money.new(opening_cash, 'IDR')
  end

  def counted_money
    counted_cash ? Money.new(counted_cash, 'IDR') : nil
  end

  def expected_money
    expected_cash ? Money.new(expected_cash, 'IDR') : nil
  end

  def variance_money
    variance ? Money.new(variance, 'IDR') : nil
  end
end
