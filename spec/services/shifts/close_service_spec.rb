require 'rails_helper'

RSpec.describe Shifts::CloseService do
  let(:cashier) { create(:staff, role: 'cashier') }
  let(:supervisor) { create(:staff, role: 'supervisor') }
  let(:shift) { create(:shift, cashier: cashier, opening_cash: 200_000, opened_at: 2.hours.ago) }

  before do
    # Cash sale 50,000 IDR for this shift's device
    order = create(:order, station_ref: shift.device_id.to_s, total_cents: 50_000, status: 'paid')
    create(:tender, order: order, method: 'cash', amount_cents: 50_000, status: 'captured', created_at: 1.hour.ago)

    # Cash sale 30,000 IDR for a DIFFERENT device (should be excluded)
    other_order = create(:order, station_ref: 'OTHER-POS', total_cents: 30_000, status: 'paid')
    create(:tender, order: other_order, method: 'cash', amount_cents: 30_000, status: 'captured', created_at: 1.hour.ago)

    # Safe drop 100,000 IDR
    create(:drawer_event, shift: shift, event_type: 'safe_drop', amount: 100_000, authorized_staff: supervisor)

    # Paid in 20,000 IDR
    create(:drawer_event, shift: shift, event_type: 'paid_in', amount: 20_000)
  end

  describe '.call (Pure Blind Close)' do
    it 'computes expected cash and variance based on cashier counted cash input, excluding other stations' do
      # Expected: 200k (opening) + 50k (cash sales on this station) - 100k (safe drop) + 20k (paid in) = 170k
      # Cashier counts 165k (5k shortage)
      result = described_class.call(
        shift: shift,
        counted_cash: 165_000,
        actor_id: cashier.id
      )

      expect(result).to be_success
      expect(shift.reload).to be_closed
      expect(shift.counted_cash).to eq(165_000)
      expect(shift.expected_cash).to eq(170_000)
      expect(shift.variance).to eq(-5_000)

      # PosAuditEvent logged
      audit = PosAuditEvent.last
      expect(audit.event_name).to eq('shift_close')
      expect(audit.payload['expected_cash']).to eq(170_000)
      expect(audit.payload['variance']).to eq(-5_000)
    end

    it 'blocks shift close when open orders exist on the station' do
      create(:order, station_ref: shift.device_id.to_s, status: 'tendering')

      expect {
        described_class.call(shift: shift, counted_cash: 200_000, actor_id: cashier.id)
      }.to raise_error(Errors::InvalidStateTransitionError, /cannot close shift with open orders/i)
    end

    it 'rejects closing an already closed shift' do
      shift.update!(closed_at: Time.current)

      expect {
        described_class.call(shift: shift, counted_cash: 200_000, actor_id: cashier.id)
      }.to raise_error(StandardError, /shift is already closed/i)
    end
  end
end
