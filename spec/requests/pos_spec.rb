require 'rails_helper'

RSpec.describe 'POS Controller', type: :request do
  let!(:staff) { create(:staff) }
  let(:device_id) { SecureRandom.uuid }

  describe 'GET /' do
    it 'routes root to pos#sell and renders Sell Inertia page' do
      get '/'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sell')
    end
  end

  describe 'GET /sell' do
    context 'when no shift is open' do
      it 'renders Sell page with nil current_shift and sample catalog' do
        get '/sell'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Sell')
      end

      it 'returns JSON format when requested' do
        get '/sell', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('catalog')
        expect(json['catalog']).to be_an(Array)
        expect(json['current_shift']).to be_nil

        # Check catalog contains items for all 3 verticals
        verticals = json['catalog'].map { |item| item['vertical'] }.uniq
        expect(verticals).to include('grocery', 'food', 'carwash')
      end
    end

    context 'when an open shift exists' do
      let!(:shift) { create(:shift, cashier: staff, device_id: device_id, opening_cash: 200_000) }
      let!(:order) { create(:order, station_ref: device_id, vertical: 'food') }

      it 'returns active current_shift and recent_orders' do
        get '/sell', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['current_shift']).to be_present
        expect(json['current_shift']['id']).to eq(shift.id)
        expect(json['recent_orders']).to be_an(Array)
        expect(json['recent_orders'].first['id']).to eq(order.id)
      end
    end
  end
end
