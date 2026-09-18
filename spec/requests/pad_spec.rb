require 'rails_helper'

RSpec.describe 'Pad Controller', type: :request do
  describe 'GET /pad' do
    it 'renders Pad Inertia page' do
      get '/pad'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Pad')
    end

    context 'when no active order exists' do
      it 'returns nil order in JSON' do
        get '/pad', params: { station_ref: 'Station-01' }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['station_ref']).to eq('Station-01')
        expect(json['order']).to be_nil
      end
    end

    context 'when active order exists for the station' do
      let!(:order) { create(:order, station_ref: 'Station-01', status: 'tendering', total_cents: 80_000) }
      let!(:line) { create(:order_line, order: order, name: 'Kopi Susu', qty: 2, unit_price_cents: 40_000, total_cents: 80_000) }

      it 'returns the active order with lines in JSON' do
        get '/pad', params: { station_ref: 'Station-01' }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['station_ref']).to eq('Station-01')
        expect(json['order']).to be_present
        expect(json['order']['id']).to eq(order.id)
        expect(json['order']['order_lines'].size).to eq(1)
        expect(json['order']['order_lines'].first['name']).to eq('Kopi Susu')
      end
    end
  end
end
