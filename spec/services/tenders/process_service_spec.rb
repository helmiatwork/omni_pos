require 'rails_helper'

RSpec.describe Tenders::ProcessService do
  let(:order) { create(:order, total_cents: 100_000, status: 'created') }
  let(:fake_wallet_client) { instance_double(OmniWalletClient) }

  describe '.call (Multi-Tender & Split Payment)' do
    it 'processes partial payment via wallet, keeping order in tendering status' do
      expect(fake_wallet_client).to receive(:debit_wallet).with(
        hash_including(amount_cents: 40_000, idempotency_key: 'idem-w1')
      ).and_return(success: true, transaction_id: 'TXN-W1')

      result = described_class.call(
        order: order,
        method: 'wallet',
        amount_cents: 40_000,
        idempotency_key: 'idem-w1',
        customer_id: 'cust-1',
        pin: '123456',
        wallet_client: fake_wallet_client
      )

      expect(result).to be_success
      expect(result.tender).to be_captured
      expect(order.reload.status).to eq('tendering')
      expect(order.captured_tenders_total_cents).to eq(40_000)
      expect(order.remaining_cents).to eq(60_000)
      expect(order.paid?).to be false
    end

    it 'transitions order to paid when subsequent cash payment completes the total balance' do
      # Pre-create 1st captured tender (wallet 40k)
      create(:tender, order: order, method: 'wallet', amount_cents: 40_000, status: 'captured')
      order.update!(status: 'tendering')

      # 2nd tender (cash 60k)
      result = described_class.call(
        order: order,
        method: 'cash',
        amount_cents: 60_000,
        idempotency_key: 'idem-cash-1'
      )

      expect(result).to be_success
      expect(order.reload.status).to eq('paid')
      expect(order.captured_tenders_total_cents).to eq(100_000)
      expect(order.remaining_cents).to eq(0)
      expect(order.paid?).to be true
    end

    it 'replays existing tender idempotently when the same idempotency_key is submitted' do
      first_result = described_class.call(
        order: order,
        method: 'cash',
        amount_cents: 50_000,
        idempotency_key: 'idem-same-key'
      )
      expect(first_result).to be_success
      expect(order.reload.captured_tenders_total_cents).to eq(50_000)

      # Re-send same key
      second_result = described_class.call(
        order: order,
        method: 'cash',
        amount_cents: 50_000,
        idempotency_key: 'idem-same-key'
      )
      expect(second_result).to be_success
      expect(second_result.tender.id).to eq(first_result.tender.id)
      expect(order.reload.captured_tenders_total_cents).to eq(50_000)
    end

    it 'rejects payment exceeding remaining balance' do
      expect {
        described_class.call(
          order: order,
          method: 'cash',
          amount_cents: 120_000,
          idempotency_key: 'idem-over'
        )
      }.to raise_error(StandardError, /exceeds remaining balance/i)
    end

    it 'raises WalletClientError when wallet debit fails' do
      expect(fake_wallet_client).to receive(:debit_wallet).and_return(success: false, error: 'Insufficient funds')

      expect {
        described_class.call(
          order: order,
          method: 'wallet',
          amount_cents: 40_000,
          idempotency_key: 'idem-fail',
          customer_id: 'cust-1',
          pin: '123456',
          wallet_client: fake_wallet_client
        )
      }.to raise_error(Errors::WalletClientError, /insufficient funds/i)
    end
  end
end
