class PosController < ApplicationController
  def sell
    current_shift = Shift.open.order(opened_at: :desc).first
    recent_orders = Order.includes(:order_lines, :tenders).order(created_at: :desc).limit(10)
    catalog = sample_catalog

    payload = {
      current_shift: current_shift&.as_json(include: :cashier),
      catalog: catalog,
      recent_orders: recent_orders.as_json(include: [:order_lines, :tenders])
    }

    respond_to do |format|
      format.html { render inertia: 'Sell', props: payload }
      format.json { render json: payload }
    end
  end

  private

  def sample_catalog
    [
      # Grocery
      {
        id: 'gro-01',
        name: 'Apel Fuji Super',
        sku: 'GRO-APL-01',
        unit_price_cents: 45_000,
        unit: 'kg',
        vertical: 'grocery',
        step: 0.1,
        category: 'Buah Segar'
      },
      {
        id: 'gro-02',
        name: 'Pisang Cavendish',
        sku: 'GRO-BAN-01',
        unit_price_cents: 28_000,
        unit: 'kg',
        vertical: 'grocery',
        step: 0.1,
        category: 'Buah Segar'
      },
      {
        id: 'gro-03',
        name: 'Susu Segar Pasteurisasi 1L',
        sku: 'GRO-MLK-01',
        unit_price_cents: 32_000,
        unit: 'item',
        vertical: 'grocery',
        step: 1.0,
        category: 'Dairy'
      },
      {
        id: 'gro-04',
        name: 'Roti Gandum Toast',
        sku: 'GRO-BRD-01',
        unit_price_cents: 22_000,
        unit: 'item',
        vertical: 'grocery',
        step: 1.0,
        category: 'Bakery'
      },
      # Food
      {
        id: 'fod-01',
        name: 'Nasi Goreng Spesial',
        sku: 'FOD-NGS-01',
        unit_price_cents: 45_000,
        unit: 'item',
        vertical: 'food',
        modifiers: [
          { name: 'Pedas', options: ['Tidak Pedas', 'Sedang', 'Pedas', 'Ekstra Pedas'] },
          { name: 'Telur', options: ['Ceplok', 'Dadar', 'Tanpa Telur'] }
        ],
        category: 'Makanan Utama'
      },
      {
        id: 'fod-02',
        name: 'Mie Goreng Seafood',
        sku: 'FOD-MGS-01',
        unit_price_cents: 48_000,
        unit: 'item',
        vertical: 'food',
        modifiers: [
          { name: 'Pedas', options: ['Sedang', 'Pedas'] }
        ],
        category: 'Makanan Utama'
      },
      {
        id: 'fod-03',
        name: 'Es Teh Manis Segar',
        sku: 'FOD-ETM-01',
        unit_price_cents: 10_000,
        unit: 'item',
        vertical: 'food',
        modifiers: [
          { name: 'Gula', options: ['Normal', 'Sedikit Gula', 'Tanpa Gula'] }
        ],
        category: 'Minuman'
      },
      # Carwash
      {
        id: 'cw-01',
        name: 'Cuci & Wax Motor / Bike',
        sku: 'CW-BIKE-01',
        unit_price_cents: 25_000,
        unit: 'item',
        vertical: 'carwash',
        tier: 'motor',
        category: 'Layanan Cuci'
      },
      {
        id: 'cw-02',
        name: 'Cuci Salju MPV / City Car',
        sku: 'CW-MPV-01',
        unit_price_cents: 60_000,
        unit: 'item',
        vertical: 'carwash',
        tier: 'mpv',
        category: 'Layanan Cuci'
      },
      {
        id: 'cw-03',
        name: 'Premium Detailing SUV / Luxury',
        sku: 'CW-SUV-01',
        unit_price_cents: 120_000,
        unit: 'item',
        vertical: 'carwash',
        tier: 'suv',
        category: 'Layanan Cuci'
      }
    ]
  end
end
