require 'rails_helper'

RSpec.describe Orders::CreateService do
  describe '.call' do
    it 'creates a grocery order with weighed decimal quantities' do
      result = described_class.call(
        station_ref: 'POS-01',
        vertical: 'grocery',
        lines: [
          { name: 'Jeruk Medan', sku: 'JRK-01', qty: 2.350, unit: 'kg', unit_price_cents: 25_000 },
          { name: 'Plastik Belanja', qty: 1, unit: 'item', unit_price_cents: 500 }
        ]
      )

      expect(result).to be_success
      order = result.order
      expect(order).to be_persisted
      expect(order.vertical).to eq('grocery')
      expect(order.status).to eq('created')
      # 2.350 * 25,000 = 58,750 + 500 = 59,250
      expect(order.total_cents).to eq(59_250)
      expect(order.order_lines.count).to eq(2)
    end

    it 'creates a food order with modifiers' do
      result = described_class.call(
        station_ref: 'Table-05',
        vertical: 'food',
        lines: [
          {
            name: 'Bakso Urat Jumbo',
            qty: 2,
            unit: 'portion',
            unit_price_cents: 35_000,
            modifiers: { pedas: 'level 3', kuah: 'rawon' }
          }
        ],
        metadata: { table_no: '05' }
      )

      expect(result).to be_success
      order = result.order
      expect(order.vertical).to eq('food')
      expect(order.total_cents).to eq(70_000)
      expect(order.metadata['table_no']).to eq('05')
    end

    it 'creates a carwash order with vehicle tier' do
      result = described_class.call(
        station_ref: 'Bay-01',
        vertical: 'carwash',
        lines: [
          { name: 'Cuci Premium + Wax', qty: 1, unit: 'service', unit_price_cents: 85_000 }
        ],
        metadata: { vehicle_plate: 'B 1234 XYZ', vehicle_tier: 'SUV' }
      )

      expect(result).to be_success
      order = result.order
      expect(order.vertical).to eq('carwash')
      expect(order.total_cents).to eq(85_000)
      expect(order.metadata['vehicle_tier']).to eq('SUV')
    end

    it 'rejects order creation when lines is empty or blank' do
      result = described_class.call(
        station_ref: 'POS-01',
        vertical: 'grocery',
        lines: []
      )

      expect(result).not_to be_success
      expect(result.error).to eq('Order must contain at least one line item')
    end

    it 'returns failure when validation fails' do
      result = described_class.call(
        station_ref: '',
        vertical: 'grocery',
        lines: [{ name: 'Item', qty: 1, unit_price_cents: 1000 }]
      )

      expect(result).not_to be_success
      expect(result.error).to be_present
    end
  end
end
