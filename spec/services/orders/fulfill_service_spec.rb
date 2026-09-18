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

    context 'when order is in a terminal or invalid state for fulfillment' do
      it 'rejects fulfillment if order is voided' do
        voided_order = create(:order, status: 'voided')
        expect {
          described_class.call(order: voided_order)
        }.to raise_error(Errors::InvalidStateTransitionError, /cannot fulfill order in voided state/i)
      end

      it 'rejects fulfillment if order is fulfilled' do
        fulfilled_order = create(:order, status: 'fulfilled')
        expect {
          described_class.call(order: fulfilled_order)
        }.to raise_error(Errors::InvalidStateTransitionError, /cannot fulfill order in fulfilled state/i)
      end
    end

    context 'when transitioning from fulfilling to fulfilled' do
      it 'marks order as fulfilled' do
        order = create(:order, vertical: 'food', status: 'fulfilling')

        result = described_class.complete(order: order)
        expect(result).to be_success
        expect(order.reload.status).to eq('fulfilled')
      end

      it 'rejects completing an order not in fulfilling state' do
        order = create(:order, vertical: 'food', status: 'created')

        expect {
          described_class.complete(order: order)
        }.to raise_error(Errors::InvalidStateTransitionError, /cannot complete order in created state/i)
      end
    end
  end
end
