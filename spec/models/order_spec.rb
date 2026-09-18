require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'validations and state helpers' do
    it 'creates a valid order in created status' do
      order = described_class.create!(
        station_ref: 'POS-01',
        vertical: 'grocery',
        total_cents: 100_000
      )

      expect(order).to be_persisted
      expect(order.status).to eq('created')
      expect(order.total_money).to eq(Money.new(100_000, 'IDR'))
      expect(order.paid?).to be false
    end

    it 'validates vertical inclusion' do
      expect(build(:order, vertical: 'space_travel')).not_to be_valid
      expect(build(:order, vertical: 'grocery')).to be_valid
      expect(build(:order, vertical: 'food')).to be_valid
      expect(build(:order, vertical: 'carwash')).to be_valid
    end

    it 'validates status inclusion' do
      expect(build(:order, status: 'unknown_status')).not_to be_valid
      %w[created tendering paid fulfilling fulfilled voided refunded].each do |st|
        expect(build(:order, status: st)).to be_valid
      end
    end

    it 'calculates total from order lines' do
      order = create(:order, total_cents: 0)
      order.order_lines.create!(name: 'Beras 5kg', qty: 1, unit: 'item', unit_price_cents: 70_000, total_cents: 70_000)
      order.order_lines.create!(name: 'Minyak 2L', qty: 2, unit: 'item', unit_price_cents: 30_000, total_cents: 60_000)

      order.recalculate_total!
      expect(order.total_cents).to eq(130_000)
      expect(order.remaining_cents).to eq(130_000)

      order.tenders.create!(method: 'cash', amount_cents: 50_000, status: 'captured', idempotency_key: SecureRandom.uuid)
      expect(order.captured_tenders_total_cents).to eq(50_000)
      expect(order.remaining_cents).to eq(80_000)
    end
  end
end
