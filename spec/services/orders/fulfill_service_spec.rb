require 'rails_helper'

RSpec.describe Orders::FulfillService do
  describe '.call' do
    context 'when vertical is carwash (Pay-First Guard)' do
      it 'rejects transition to fulfilling if order is not paid' do
        unpaid_order = create(:order, vertical: 'carwash', status: 'created')

        expect {
          described_class.call(order: unpaid_order)
        }.to raise_error(Errors::PayFirstViolationError, /carwash orders must be paid/i)
      end

      it 'allows transition to fulfilling when carwash order is paid and allocates bay queue' do
        paid_order = create(:order, vertical: 'carwash', status: 'paid', metadata: { vehicle_plate: 'B 1234 XYZ' })

        result = described_class.call(order: paid_order)
        expect(result).to be_success
        expect(paid_order.reload.status).to eq('fulfilling')
        expect(paid_order.metadata['bay_queue']).to be_present
      end
    end

    context 'when transitioning from fulfilling to fulfilled' do
      it 'marks order as fulfilled' do
        order = create(:order, vertical: 'food', status: 'fulfilling')

        result = described_class.complete(order: order)
        expect(result).to be_success
        expect(order.reload.status).to eq('fulfilled')
      end
    end
  end
end
