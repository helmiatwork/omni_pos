require 'rails_helper'

RSpec.describe 'Orders Controller', type: :request do
  let!(:staff) { create(:staff) }

  describe 'GET /orders' do
    let!(:order1) { create(:order, vertical: 'grocery', status: 'created', station_ref: 'Station-01') }
    let!(:order2) { create(:order, vertical: 'food', status: 'paid', station_ref: 'Station-02') }

    it 'renders Orders Inertia page' do
      get '/orders'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Orders')
    end

    it 'returns orders as JSON with filtering' do
      get '/orders', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['orders'].size).to eq(2)

      get '/orders', params: { vertical: 'grocery' }, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      expect(json['orders'].size).to eq(1)
      expect(json['orders'].first['vertical']).to eq('grocery')

      get '/orders', params: { status: 'paid' }, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      expect(json['orders'].size).to eq(1)
      expect(json['orders'].first['status']).to eq('paid')
    end
  end

  describe 'POST /orders' do
    let(:valid_params) do
      {
        station_ref: 'Station-01',
        vertical: 'grocery',
        lines: [
          { name: 'Apples', sku: 'GRO-APL', qty: 1.5, unit: 'kg', unit_price_cents: 40_000 }
        ]
      }
    end

    it 'creates an order and returns 201 JSON' do
      post '/orders', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['order']['total_cents']).to eq(60_000)
    end

    it 'redirects on HTML request' do
      post '/orders', params: valid_params
      expect(response).to have_http_status(:found)
    end

    it 'returns 422 when lines are empty' do
      post '/orders', params: { station_ref: 'Station-01', vertical: 'grocery', lines: [] }.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to include('at least one line item')
    end

    it 'returns 422 when vertical is invalid' do
      post '/orders', params: { station_ref: 'Station-01', vertical: 'invalid', lines: [{ name: 'Test', qty: 1, unit_price_cents: 10_000 }] }.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe 'POST /orders/:id/fulfill' do
    context 'grocery or food order' do
      let!(:order) { create(:order, vertical: 'food', status: 'created') }

      it 'transitions order to fulfilling' do
        post "/orders/#{order.id}/fulfill", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        expect(order.reload.status).to eq('fulfilling')
      end
    end

    context 'carwash order pay-first rule' do
      let!(:unpaid_carwash) { create(:order, vertical: 'carwash', status: 'created') }
      let!(:paid_carwash) { create(:order, vertical: 'carwash', status: 'paid', total_cents: 50_000) }

      it 'rejects unpaid carwash order with 422 PayFirstViolationError' do
        post "/orders/#{unpaid_carwash.id}/fulfill", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Carwash orders must be paid before fulfilling')
      end

      it 'fulfills paid carwash order and assigns bay queue' do
        post "/orders/#{paid_carwash.id}/fulfill", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        expect(paid_carwash.reload.status).to eq('fulfilling')
        expect(paid_carwash.metadata['bay_queue']).to be_present
      end
    end

    context 'invalid state transition' do
      let!(:voided_order) { create(:order, status: 'voided') }

      it 'returns 422 when fulfilling voided order' do
        post "/orders/#{voided_order.id}/fulfill", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Cannot fulfill order in voided state')
      end
    end

    context 'when order is not found' do
      it 'returns 404' do
        post "/orders/#{SecureRandom.uuid}/fulfill", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /orders/:id/complete' do
    let!(:fulfilling_order) { create(:order, status: 'fulfilling') }
    let!(:created_order) { create(:order, status: 'created') }

    it 'completes fulfilling order' do
      post "/orders/#{fulfilling_order.id}/complete", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(fulfilling_order.reload.status).to eq('fulfilled')
    end

    it 'returns 422 if order is not in fulfilling state' do
      post "/orders/#{created_order.id}/complete", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Cannot complete order in created state')
    end
  end

  describe 'POST /orders/:id/void' do
    let!(:order) { create(:order, status: 'created', total_cents: 50_000) }

    it 'voids order and logs audit event' do
      expect do
        post "/orders/#{order.id}/void", params: { reason: 'Customer changed mind', actor_id: staff.id }, headers: { 'Accept' => 'application/json' }
      end.to change(PosAuditEvent, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq('voided')
    end

    it 'returns 422 if order is already fulfilled' do
      order.update!(status: 'fulfilled')
      post "/orders/#{order.id}/void", params: { reason: 'Test', actor_id: staff.id }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Cannot void fulfilled order')
    end

    it 'returns 422 if order has captured tenders' do
      create(:tender, order: order, amount_cents: 50_000, status: 'captured', idempotency_key: 'tx-captured-1')
      post "/orders/#{order.id}/void", params: { reason: 'Test', actor_id: staff.id }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('issue refund instead')
    end
  end
end
