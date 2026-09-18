require 'rails_helper'

RSpec.describe OrderLine, type: :model do
  let(:order) { create(:order) }

  describe 'validations and calculations' do
    it 'supports decimal quantities for weighed grocery items' do
      line = described_class.create!(
        order: order,
        name: 'Daging Sapi',
        sku: 'BEEF-01',
        qty: 1.250,
        unit: 'kg',
        unit_price_cents: 120_000,
        total_cents: 150_000
      )

      expect(line.qty).to eq(1.250)
      expect(line.total_cents).to eq(150_000)
      expect(line.unit_price_money).to eq(Money.new(120_000, 'IDR'))
      expect(line.total_money).to eq(Money.new(150_000, 'IDR'))
    end

    it 'automatically computes total_cents if not provided' do
      line = described_class.new(
        order: order,
        name: 'Tomat Segar',
        qty: 2.5,
        unit: 'kg',
        unit_price_cents: 10_000
      )
      line.save!
      expect(line.total_cents).to eq(25_000)
    end
  end
end
