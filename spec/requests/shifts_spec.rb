require 'rails_helper'

RSpec.describe 'Shifts Controller', type: :request do
  let!(:staff) { create(:staff) }
  let(:device_id) { SecureRandom.uuid }

  describe 'GET /shifts' do
    let!(:shift) { create(:shift, device_id: device_id, cashier: staff, opening_cash: 100_000) }

    it 'renders Shift Inertia page' do
      get '/shifts'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Shift')
    end

    it 'returns shift data as JSON' do
      get '/shifts', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('current_shift')
      expect(json['current_shift']['id']).to eq(shift.id)
      expect(json).to have_key('past_shifts')
      expect(json).to have_key('audit_logs')
    end
  end

  describe 'POST /shifts/open' do
    it 'creates an open shift and returns 201' do
      post '/shifts/open',
           params: { device_id: device_id, cashier_id: staff.id, opening_cash: 300_000 },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['shift']['opening_cash']).to eq(300_000)
    end

    it 'handles negative opening cash with 422' do
      post '/shifts/open',
           params: { device_id: device_id, cashier_id: staff.id, opening_cash: -10_000 },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe 'POST /shifts/:id/close' do
    let!(:shift) { create(:shift, device_id: device_id, cashier: staff, opening_cash: 200_000) }

    it 'successfully closes shift and calculates variance' do
      post "/shifts/#{shift.id}/close",
           params: { counted_cash: 205_000, actor_id: staff.id },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['variance']).to eq(5_000)
      expect(shift.reload.closed?).to be true
    end

    it 'rejects closing shift with open orders with 422' do
      create(:order, station_ref: shift.device_id.to_s, status: 'created')

      post "/shifts/#{shift.id}/close",
           params: { counted_cash: 200_000, actor_id: staff.id },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Cannot close shift with open orders')
    end

    it 'rejects closing an already closed shift with 422' do
      shift.update!(closed_at: Time.current, counted_cash: 200_000, expected_cash: 200_000, variance: 0)

      post "/shifts/#{shift.id}/close",
           params: { counted_cash: 200_000, actor_id: staff.id },
           headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Shift is already closed')
    end

    it 'returns 404 when shift is not found' do
      post "/shifts/#{SecureRandom.uuid}/close",
           params: { counted_cash: 200_000 },
           headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
