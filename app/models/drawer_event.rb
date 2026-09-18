class DrawerEvent < ApplicationRecord
  EVENT_TYPES = %w[safe_drop paid_in paid_out].freeze

  belongs_to :shift
  belongs_to :authorized_staff, class_name: 'Staff', foreign_key: :authorized_by, optional: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :amount, numericality: { greater_than: 0 }

  def amount_money
    Money.new(amount, 'IDR')
  end
end
