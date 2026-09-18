require 'rails_helper'

RSpec.describe OmniWalletClient do
  let(:client) { described_class.new(base_url: 'http://localhost:3000', device_key: 'device-test-secret') }

  describe '#lookup_customer' do
    it 'returns customer profile on successful lookup' do
      fake_response = instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: {
        customer: { id: 'cust-123', name: 'Siti', phone: '+62811111111', balance_cents: 250_000 }
      }.to_json)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      res = client.lookup_customer(phone: '+62811111111')
      expect(res[:success]).to be true
      expect(res[:customer]['name']).to eq('Siti')
      expect(res[:customer]['balance_cents']).to eq(250_000)
    end
  end

  describe '#debit_wallet' do
    it 'posts signed purchase request to omniWallet' do
      fake_response = instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: {
        success: true,
        transaction_id: 'TXN-9988',
        amount_cents: 50_000
      }.to_json)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      res = client.debit_wallet(
        customer_id: 'cust-123',
        merchant_id: 'merch-456',
        amount_cents: 50_000,
        pin: '123456',
        idempotency_key: 'idem-uuid-001',
        order_id: 'ord-001'
      )

      expect(res[:success]).to be true
      expect(res[:transaction_id]).to eq('TXN-9988')
    end

    it 'attaches replay protection headers and includes timestamp and nonce in signature' do
      fake_response = instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: {
        success: true,
        transaction_id: 'TXN-9988'
      }.to_json)

      expect_any_instance_of(Net::HTTP).to receive(:request) do |_, req|
        expect(req['X-Device-Signature']).to be_present
        expect(req['X-Device-Timestamp']).to be_present
        expect(req['X-Device-Nonce']).to be_present

        expected_sig = client.send(
          :generate_signature,
          req.method,
          '/v1/transfers/purchase',
          req.body,
          timestamp: req['X-Device-Timestamp'],
          nonce: req['X-Device-Nonce']
        )
        expect(req['X-Device-Signature']).to eq(expected_sig)

        fake_response
      end

      client.debit_wallet(
        customer_id: 'cust-123',
        merchant_id: 'merch-456',
        amount_cents: 50_000,
        pin: '123456',
        idempotency_key: 'idem-uuid-001',
        order_id: 'ord-001'
      )
    end

    it 'handles network timeout and marks status as unknown for recovery' do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout)

      res = client.debit_wallet(
        customer_id: 'cust-123',
        merchant_id: 'merch-456',
        amount_cents: 50_000,
        pin: '123456',
        idempotency_key: 'idem-uuid-timeout',
        order_id: 'ord-001'
      )

      expect(res[:success]).to be false
      expect(res[:status]).to eq(:unknown)
      expect(res[:error]).to match(/timeout/i)
    end
  end

  describe '#get_tender_by_key' do
    it 'queries transaction status by idempotency key' do
      fake_response = instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: {
        found: true,
        transaction: { id: 'TXN-9988', status: 'captured' }
      }.to_json)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      res = client.get_tender_by_key(idempotency_key: 'idem-uuid-001')
      expect(res[:found]).to be true
      expect(res['found']).to be true
      expect(res[:transaction]['status']).to eq('captured')
      expect(res['transaction'][:status]).to eq('captured')
    end
  end

  describe '#verify_pin' do
    it 'posts pin verification request' do
      fake_response = instance_double(Net::HTTPSuccess, is_a?: true, code: '200', body: {
        valid: true
      }.to_json)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      res = client.verify_pin(customer_id: 'cust-123', pin: '123456')
      expect(res[:success]).to be true
      expect(res['success']).to be true
      expect(res[:valid]).to be true
      expect(res['valid']).to be true
    end
  end

  describe 'error handling' do
    it 'handles HTTP error response' do
      fake_response = instance_double(Net::HTTPClientError, is_a?: false, code: '400', message: 'Bad Request', body: {
        error: 'Invalid parameters'
      }.to_json)
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)

      res = client.lookup_customer(phone: '+62800000000')
      expect(res[:success]).to be false
      expect(res[:status]).to eq(:error)
      expect(res[:code]).to eq(400)
      expect(res[:error]).to eq('Invalid parameters')
    end

    it 'handles general StandardError' do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(StandardError.new('Unexpected failure'))

      res = client.lookup_customer(phone: '+62800000000')
      expect(res[:success]).to be false
      expect(res[:status]).to eq(:failed)
      expect(res[:error]).to eq('Unexpected failure')
    end
  end
end
