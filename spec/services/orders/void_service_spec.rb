require 'rails_helper'

RSpec.describe Orders::VoidService do
  let(:actor_id) { SecureRandom.uuid }

  describe '.call' do
    it 'voids an unfulfilled order and logs a pos audit event' do
      order = create(:order, status: 'created')

      result = described_class.call(order: order, reason: 'Wrong station entry', actor_id: actor_id)

      expect(result).to be_success
      expect(order.reload.status).to eq('voided')

      audit = PosAuditEvent.last
      expect(audit.event_name).to eq('void')
      expect(audit.payload['order_id']).to eq(order.id)
      expect(audit.payload['reason']).to eq('Wrong station entry')
    end

    it 'rejects voiding an already fulfilled order' do
      fulfilled_order = create(:order, status: 'fulfilled')

      expect {
        described_class.call(order: fulfilled_order, reason: 'Customer returned', actor_id: actor_id)
      }.to raise_error(Errors::InvalidStateTransitionError, /cannot void fulfilled order/i)
    end
  end
end
