require 'rails_helper'

RSpec.describe 'Tenders Controller', type: :request do
  let!(:order) { create(:order, status: 'created', total_cents: 100_000) }

  describe 'POST /orders/:id/tenders' do
    let(:idempotency_key) { SecureRandom.uuid }

    context 'with cash tender' do
      it 'captures partial payment and updates status to tendering' do
        post "/orders/#{order.id}/tenders",
             params: { method: 'cash', amount_cents: 40_000, idempotency_key: idempotency_key },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['tender']['amount_cents']).to eq(40_000)
        expect(order.reload.status).to eq('tendering')
      end

      it 'captures full payment and updates status to paid' do
        post "/orders/#{order.id}/tenders",
             params: { method: 'cash', amount_cents: 100_000, idempotency_key: idempotency_key },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:created)
        expect(order.reload.status).to eq('paid')
      end

      it 'is idempotent when submitted with the same idempotency_key' do
        post "/orders/#{order.id}/tenders",
             params: { method: 'cash', amount_cents: 50_000, idempotency_key: idempotency_key },
             headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:created)

        # Retry identical tender
        expect do
          post "/orders/#{order.id}/tenders",
               params: { method: 'cash', amount_cents: 50_000, idempotency_key: idempotency_key },
               headers: { 'Accept' => 'application/json' }
        end.not_to change(Tender, :count)

        expect(response).to have_http_status(:created).or have_http_status(:ok)
      end
    end

    context 'with wallet tender' do
      let(:mock_client) { instance_double(OmniWalletClient) }

      it 'calls OmniWalletClient and captures wallet tender' do
        allow(OmniWalletClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:debit_wallet).and_return({
          success: true,
          transaction_id: 'tx_wallet_999'
        })

        post "/orders/#{order.id}/tenders",
             params: {
               method: 'wallet',
               amount_cents: 100_000,
               idempotency_key: idempotency_key,
               customer_id: 'cust-123',
               pin: '123456'
             },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['tender']['method']).to eq('wallet')
        expect(json['tender']['reference_id']).to eq('tx_wallet_999')
        expect(order.reload.status).to eq('paid')
      end

      it 'handles wallet client failure gracefully with 422' do
        allow(OmniWalletClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:debit_wallet).and_return({
          success: false,
          error: 'Insufficient balance in wallet'
        })

        post "/orders/#{order.id}/tenders",
             params: {
               method: 'wallet',
               amount_cents: 100_000,
               idempotency_key: idempotency_key,
               customer_id: 'cust-123',
               pin: '123456'
             },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Insufficient balance')
      end
    end

    context 'error states' do
      it 'rejects overpayment with 422 TenderExceedsBalanceError' do
        post "/orders/#{order.id}/tenders",
             params: { method: 'cash', amount_cents: 150_000, idempotency_key: idempotency_key },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Payment exceeds remaining balance')
      end

      it 'rejects payment for already paid/fulfilled order' do
        order.update!(status: 'fulfilled')
        post "/orders/#{order.id}/tenders",
             params: { method: 'cash', amount_cents: 50_000, idempotency_key: idempotency_key },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Cannot process payment for order in fulfilled state')
      end
    end
  end
end
