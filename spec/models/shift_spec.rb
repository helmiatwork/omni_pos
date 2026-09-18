require 'rails_helper'

RSpec.describe Shift, type: :model do
  let(:cashier) { create(:staff, role: 'cashier') }

  describe 'associations & state' do
    it 'creates an open shift' do
      shift = described_class.create!(
        device_id: SecureRandom.uuid,
        cashier: cashier,
        opening_cash: 200_000
      )

      expect(shift).to be_opened
      expect(shift).not_to be_closed
      expect(shift.opening_cash).to eq(200_000)
    end

    it 'validates cashier presence' do
      shift = build(:shift, cashier: nil)
      expect(shift).not_to be_valid
    end

    it 'prevents negative opening cash' do
      shift = build(:shift, cashier: cashier, opening_cash: -10)
      expect(shift).not_to be_valid
    end

    it 'computes money helpers and closed state' do
      shift = create(:shift, cashier: cashier, opening_cash: 200_000, counted_cash: 250_000, expected_cash: 250_000, variance: 0, closed_at: Time.current)
      expect(shift).to be_closed
      expect(shift).not_to be_opened
      expect(shift.opening_money).to eq(Money.new(200_000, 'IDR'))
      expect(shift.counted_money).to eq(Money.new(250_000, 'IDR'))
      expect(shift.expected_money).to eq(Money.new(250_000, 'IDR'))
      expect(shift.variance_money).to eq(Money.new(0, 'IDR'))
    end
  end
end
